require "digest"
require "fileutils"
require "find"
require "json"
require "pathname"
require "tempfile"
require "time"
require "tmpdir"

File.umask(0077)

def current_roots
  home = File.expand_path(ENV.fetch("HOME"))
  config = ENV["XDG_CONFIG_HOME"]
  config = File.join(home, ".config") if config.nil? || config.empty?
  config = File.expand_path(config)
  { "home" => home, "config" => config }
end

def configuration_current?(source, managed_home_files)
  roots = current_roots
  files = managed_home_files.map { |name| [File.join(source, name), File.join(roots.fetch("home"), name)] }
  %w[nvim ghostty].each do |application|
    base = File.realpath(File.join(source, application, ".config", application))
    Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH).each do |path|
      next unless File.file?(path)
      relative = Pathname.new(path).relative_path_from(Pathname.new(base)).to_s
      files << [path, File.join(roots.fetch("config"), application, relative)]
    end
  end
  settings = File.join(roots.fetch("config"), "dotfiles")
  platform = ENV.fetch("DOTFILES_PLATFORM")
  files.concat([
    [File.join(source, "common/shell/environment.sh"), File.join(settings, "environment.sh")],
    [File.join(source, "platforms", platform, "shell.sh"), File.join(settings, "platform.d/shell.sh")],
    [File.join(source, "platforms", platform, "ghostty.conf"), File.join(settings, "platform.d/ghostty.conf")],
    [File.join(source, "profiles/work/shell.zsh"), File.join(settings, "profiles/work/shell.zsh")]
  ])
  return false unless files.all? { |original, destination| File.file?(destination) && File.binread(original) == File.binread(destination) }
  selectors = {
    "profile" => ENV.fetch("DOTFILES_PROFILE"),
    "platform" => ENV.fetch("DOTFILES_PLATFORM"),
    "package-set" => ENV.fetch("DOTFILES_PACKAGE_SET", "workstation")
  }
  selectors.each do |selector, value|
    destination = File.join(settings, selector)
    return false unless File.file?(destination) && File.binread(destination) == value + "\n"
  end
  private_environment = File.join(roots.fetch("home"), ".private_env")
  File.file?(private_environment) && (File.stat(private_environment).mode & 0777) == 0600
end

def resolved_path(path)
  parent = File.expand_path(path)
  suffix = []
  until File.exist?(parent) || File.symlink?(parent)
    suffix.unshift(File.basename(parent))
    parent = File.dirname(parent)
  end
  File.join(File.realpath(parent), *suffix)
end

def within?(path, root)
  path == root || path.start_with?(root + "/")
end

def write_manifest(directory, manifest)
  Tempfile.create([".manifest-", ".json"], directory) do |file|
    file.chmod(0600)
    file.write(JSON.pretty_generate(manifest) + "\n")
    file.flush
    file.fsync
    File.rename(file.path, File.join(directory, "manifest.json"))
  end
end

def destination_for(relative, manifest)
  parts = relative.split("/")
  raise "Invalid backup path: #{relative}" if parts.any? { |part| part.empty? || part == "." || part == ".." } || relative.start_with?("/")
  if parts.length == 2 && parts[0] == "home" && manifest.fetch("managed_home_files").include?(parts[1])
    File.join(manifest.fetch("roots").fetch("home"), parts[1])
  elsif parts.length >= 3 && parts[0] == "config" && %w[nvim ghostty dotfiles].include?(parts[1])
    File.join(manifest.fetch("roots").fetch("config"), *parts.drop(1))
  else
    raise "Unmanaged backup path: #{relative}"
  end
end

def file_checksum(path, stat)
  stat.symlink? ? Digest::SHA256.hexdigest(File.readlink(path)) : Digest::SHA256.file(path).hexdigest
end

def create_manifest(directory, source, managed_home_files, action = "deployment")
  raise "Managed home files are missing" if managed_home_files.empty?
  manifest = {
    "version" => 1,
    "created_at" => Time.now.utc.iso8601,
    "source" => File.expand_path(source),
    "roots" => current_roots,
    "physical_roots" => current_roots.transform_values { |path| resolved_path(path) },
    "managed_home_files" => managed_home_files.sort,
    "selectors" => {
      "platform" => ENV.fetch("DOTFILES_PLATFORM", "macos"),
      "profile" => ENV.fetch("DOTFILES_PROFILE", "personal"),
      "package_set" => ENV.fetch("DOTFILES_PACKAGE_SET", "workstation")
    },
    "action" => action,
    "status" => "in_progress",
    "entries" => []
  }
  write_manifest(directory, manifest)
end

def finalize_manifest(directory, exit_code)
  manifest = JSON.parse(File.read(File.join(directory, "manifest.json")))
  entries = []
  %w[home config/nvim config/ghostty config/dotfiles].each do |prefix|
    base = File.join(directory, prefix)
    next unless File.directory?(base)
    Find.find(base) do |path|
      stat = File.lstat(path)
      next if stat.directory?
      raise "Unsupported backup file: #{path}" unless stat.file? || stat.symlink?
      relative = Pathname.new(path).relative_path_from(Pathname.new(directory)).to_s
      entries << {
        "backup" => relative,
        "destination" => destination_for(relative, manifest),
        "type" => stat.symlink? ? "symlink" : "file",
        "mode" => stat.mode & 0777,
        "sha256" => file_checksum(path, stat)
      }
    end
  end
  manifest["entries"] = entries.sort_by { |entry| entry.fetch("backup") }
  manifest["status"] = exit_code.zero? ? "complete" : "failed"
  manifest["exit_code"] = exit_code
  manifest["finished_at"] = Time.now.utc.iso8601
  write_manifest(directory, manifest)
end

def verified_restore_entries(directory, managed_home_files)
  directory_stat = File.stat(directory)
  raise "Backup directory must be owned by you and not writable by others" unless directory_stat.uid == Process.uid && (directory_stat.mode & 0022).zero?
  manifest_path = File.join(directory, "manifest.json")
  manifest_stat = File.lstat(manifest_path)
  raise "Unsafe backup manifest" unless manifest_stat.file? && manifest_stat.uid == Process.uid && (manifest_stat.mode & 0022).zero?
  manifest = JSON.parse(File.read(manifest_path))
  raise "Unsupported backup manifest" unless manifest["version"] == 1 && %w[complete failed].include?(manifest["status"]) && manifest["entries"].is_a?(Array)
  raise "Backup belongs to different home or config roots" unless manifest["roots"] == current_roots
  physical_roots = current_roots.transform_values { |path| resolved_path(path) }
  raise "Backup destination roots have changed" unless manifest["physical_roots"] == physical_roots
  saved_home_files = manifest["managed_home_files"]
  raise "Backup managed-file list does not match this checkout" unless saved_home_files.is_a?(Array) && !saved_home_files.empty? && (saved_home_files - managed_home_files).empty?
  if manifest["selectors"]
    raise "Invalid backup selectors" unless %w[macos ubuntu].include?(manifest["selectors"]["platform"]) && %w[personal work].include?(manifest["selectors"]["profile"])
    if manifest["selectors"].key?("package_set")
      raise "Invalid backup package set" unless %w[workstation homelab].include?(manifest["selectors"]["package_set"])
    end
  end

  seen = []
  manifest["entries"].map do |entry|
    relative = entry.fetch("backup")
    destination = destination_for(relative, manifest)
    raise "Backup destination does not match its recorded path" unless entry["destination"] == destination
    raise "Duplicate backup entry" if seen.include?(relative)
    seen << relative
    source = File.join(directory, relative)
    raise "Backup source escapes its directory" unless within?(resolved_path(File.dirname(source)), directory)
    stat = File.lstat(source)
    expected_type = stat.symlink? ? "symlink" : "file"
    raise "Unsupported backup file type" unless (stat.file? || stat.symlink?) && entry["type"] == expected_type
    raise "Backup checksum or permissions do not match" unless entry["sha256"] == file_checksum(source, stat) && entry["mode"] == (stat.mode & 0777)
    root_name = relative.start_with?("home/") ? "home" : "config"
    raise "Restore destination crosses a symlink boundary" unless within?(resolved_path(File.dirname(destination)), physical_roots.fetch(root_name))
    raise "Restore destination is a directory: #{destination}" if File.directory?(destination)
    [entry, source, destination]
  end
end

def restore_backup(directory, dry_run, managed_home_files)
  directory = File.realpath(directory)
  entries = verified_restore_entries(directory, managed_home_files)
  if entries.empty?
    puts "Nothing to restore: this backup has no replaced files."
    return
  end
  entries.each { |entry, _source, destination| puts "Restore #{entry.fetch("backup")} -> #{destination}" }
  return if dry_run
  print "Type restore to confirm replacing these files with rollback backups: "
  $stdout.flush
  unless $stdin.gets.to_s.strip == "restore"
    puts "Cancelled."
    return
  end
  confirmed_entries = verified_restore_entries(directory, managed_home_files)
  raise "Backup changed while confirmation was pending" unless confirmed_entries == entries

  state = ENV["XDG_STATE_HOME"]
  state = File.join(current_roots.fetch("home"), ".local/state") if state.nil? || state.empty?
  backup_base = File.join(File.expand_path(state), "dotfiles/backups")
  FileUtils.mkdir_p(backup_base)
  rollback = Dir.mktmpdir("restore-#{Time.now.utc.strftime("%Y%m%d-%H%M%S")}-", backup_base)
  create_manifest(rollback, directory, managed_home_files, "restore")
  puts "Rollback backup: #{rollback}"
  exit_code = 1
  begin
    entries.each do |entry, source, destination|
      FileUtils.mkdir_p(File.dirname(destination))
      backup_path = File.join(rollback, File.dirname(entry.fetch("backup")))
      success = system("rsync", "-a", "--checksum", "--backup", "--backup-dir=#{backup_path}", source, destination)
      raise "Restore copy failed: #{destination}" unless success
    end
    exit_code = 0
  ensure
    finalize_manifest(rollback, exit_code)
  end
  puts "Restored saved files. Files absent from the backup were not deleted."
end

begin
  command = ARGV.shift
  directory = File.expand_path(ARGV.shift || raise("Backup directory is required"))
  case command
  when "check"
    exit(configuration_current?(directory, ARGV) ? 0 : 3)
  when "init"
    create_manifest(directory, ARGV.shift || raise("Source directory is required"), ARGV)
  when "finalize"
    finalize_manifest(directory, Integer(ARGV.shift || raise("Exit code is required")))
  when "restore"
    dry_run = ARGV.shift
    raise "Restore preview flag is invalid" unless %w[true false].include?(dry_run)
    restore_backup(directory, dry_run == "true", ARGV)
  else
    raise "Unknown backup command"
  end
rescue StandardError => error
  warn "Backup error: #{error.message}"
  exit 1
end
