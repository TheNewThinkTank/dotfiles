require "fileutils"
require "json"
require "open3"
require "tmpdir"

File.umask(0077)

def setting_command(*arguments)
  output, errors, result = Open3.capture3("gsettings", *arguments)
  raise "GNOME settings command failed: #{errors.strip}" unless result.success?
  output.strip
end

begin
  settings = JSON.parse(File.read(File.join(__dir__, "desktop-settings.json")))
  preview = false
  restore = nil
  until ARGV.empty?
    case ARGV.shift
    when "--dry-run" then preview = true
    when "--restore" then restore = ARGV.shift || raise("Restore snapshot is required")
    else raise "Usage: ruby platforms/ubuntu/desktop.rb [--dry-run] [--restore SNAPSHOT]"
    end
  end
  if restore
    stat = File.lstat(restore)
    raise "Unsafe desktop snapshot" unless stat.file? && stat.uid == Process.uid && (stat.mode & 0022).zero?
    snapshot = JSON.parse(File.read(restore))
    raise "Unsupported desktop snapshot" unless snapshot["version"] == 1 && snapshot["home"] == File.expand_path(ENV.fetch("HOME"))
    restored = snapshot.fetch("settings")
    allowed = settings.map { |setting| [setting.fetch("schema"), setting.fetch("key")] }.sort
    raise "Desktop snapshot scope mismatch" unless restored.map { |setting| [setting.fetch("schema"), setting.fetch("key")] }.sort == allowed
    raise "Invalid desktop snapshot value" unless restored.all? { |setting| setting["value"].is_a?(String) }
    settings = restored
  end
  settings.each { |setting| puts "#{setting.fetch("schema")} #{setting.fetch("key")} = #{setting.fetch("value")}" }
  exit 0 if preview
  raise "Run this command in your GNOME desktop session" unless ENV.fetch("XDG_CURRENT_DESKTOP", "").include?("GNOME") && !ENV.fetch("DBUS_SESSION_BUS_ADDRESS", "").empty?
  original = settings.map do |setting|
    setting.merge("value" => setting_command("get", setting.fetch("schema"), setting.fetch("key")))
  end
  print "Type desktop to confirm changing only these shortcuts: "
  $stdout.flush
  unless $stdin.gets.to_s.strip == "desktop"
    puts "Cancelled."
    exit 0
  end
  state = ENV["XDG_STATE_HOME"]
  state = File.join(ENV.fetch("HOME"), ".local/state") if state.nil? || state.empty?
  base = File.join(File.expand_path(state), "dotfiles/desktop-backups")
  FileUtils.mkdir_p(base)
  directory = Dir.mktmpdir("gnome-", base)
  backup = File.join(directory, "settings.json")
  File.write(backup, JSON.pretty_generate({ "version" => 1, "home" => File.expand_path(ENV.fetch("HOME")), "settings" => original }) + "\n", mode: "w", perm: 0600)
  puts "Desktop backup: #{backup}"
  begin
    settings.each { |setting| setting_command("set", setting.fetch("schema"), setting.fetch("key"), setting.fetch("value")) }
  rescue StandardError
    original.each do |setting|
      Open3.capture3("gsettings", "set", setting.fetch("schema"), setting.fetch("key"), setting.fetch("value"))
    end
    raise
  end
  puts "Desktop shortcuts applied. Alt-j/k remain available to terminals and editors."
rescue StandardError => error
  warn "Desktop setup failed: #{error.message}"
  exit 1
end
