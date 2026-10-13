require "fileutils"
require "json"
require "open3"
require "openssl"
require "tmpdir"

def export_trusted_host_certificates(source)
  raise "Host certificate export currently requires macOS" unless RUBY_PLATFORM.include?("darwin")
  directory = File.join(source, ".docker-ca")
  FileUtils.mkdir_p(directory)
  certificates = []
  keychains = [
    "/System/Library/Keychains/SystemRootCertificates.keychain",
    "/Library/Keychains/System.keychain",
    File.join(Dir.home, "Library/Keychains/login.keychain-db")
  ]
  keychains.select { |path| File.file?(path) }.each do |keychain|
    output, _errors, result = Open3.capture3("security", "find-certificate", "-a", "-p", keychain)
    next unless result.success?
    output.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).each do |pem|
      certificate = OpenSSL::X509::Certificate.new(pem)
      next unless certificate.extensions.any? { |extension| extension.oid == "basicConstraints" && extension.value.include?("CA:TRUE") }
      candidate = File.join(directory, "candidate.pem")
      File.write(candidate, certificate.to_pem)
      _verification, _diagnostics, trusted = Open3.capture3("security", "verify-cert", "-q", "-p", "basic", "-c", candidate)
      certificates << certificate.to_pem if trusted.success?
    end
  end
  raise "No macOS-trusted CA certificates were available" if certificates.empty?
  File.write(File.join(directory, "roots.pem"), certificates.uniq.join)
  FileUtils.rm_f(File.join(directory, "candidate.pem"))
  puts "Exported #{certificates.uniq.length} public, macOS-verified CA certificates for this test container."
end

root = File.expand_path("..", __dir__)
results = Dir.mktmpdir("dotfiles-ubuntu-results-")
success = false
Dir.mktmpdir("dotfiles-ubuntu-source-") do |source|
  paths = %w[
    bootstrap.sh Makefile README.md LICENSE private_env.template plugins.lock.json
    .aerospace.toml .bashrc .editorconfig .gitconfig .p10k.zsh .shrc .tmux.conf
    .vimrc .zshenv .zshrc Brewfile common platforms profiles scripts tests .github
    nvim ghostty
  ]
  paths.each do |path|
    FileUtils.cp_r(File.join(root, path), File.join(source, path), preserve: true, dereference_root: false)
  end
  use_host_certificates = ENV["DOTFILES_DOCKER_USE_HOST_CA"] == "1"
  export_trusted_host_certificates(source) if use_host_certificates
  git_environment = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_NOSYSTEM" => "1" }
  abort "Could not initialize test metadata" unless system(git_environment, "git", "init", "--quiet", source)
  arguments = [
    "docker", "run", "--rm", "--mount", "type=bind,source=#{source},target=/workspace,readonly",
    "--workdir", "/workspace", "--env", "HOME=/tmp/dotfiles-ubuntu-home",
    "--env", "DOTFILES_PLATFORM=ubuntu"
  ]
  arguments.concat(["--env", "DOTFILES_DOCKER_CA_FILE=/workspace/.docker-ca/roots.pem"]) if use_host_certificates
  arguments.concat(["ubuntu:26.04", "bash", "tests/ubuntu.sh"])
  puts "Starting native Ubuntu 26.04 checks. Full log: #{results}/output.log"
  $stdout.flush
  File.open(File.join(results, "output.log"), "w", 0600) do |log|
    Open3.popen2e(*arguments) do |input, output, process|
      input.close
      records = 0
      output.each_line do |line|
        log.write(line)
        log.flush
        records += 1
        if (records % 150).zero? || line.match?(/Native Ubuntu|All real pinned|^ok [0-9]|^not ok|^Error|^E:|^curl:/)
          puts line.strip
          $stdout.flush
        end
      end
      result = process.value
      success = result.success?
      File.write(File.join(results, "result.json"), JSON.generate({ "exit_code" => result.exitstatus, "success" => success }) + "\n")
      puts "UBUNTU_EXIT_CODE=#{result.exitstatus}"
    end
  end
end
puts "UBUNTU_RESULTS=#{results}"
exit(success ? 0 : 1)
