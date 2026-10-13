require "json"
require "open3"

class BrewManifest
  attr_reader :formulae, :casks

  def initialize
    @formulae = []
    @casks = []
  end

  def brew(name, **_options)
    @formulae << name
  end

  def cask(name, **_options)
    @casks << name
  end

  %i[tap vscode npm].each do |directive|
    define_method(directive) { |*_arguments, **_options| }
  end
end

begin
  manifest = BrewManifest.new
  manifest.instance_eval(File.read(ARGV[0] || File.expand_path("../Brewfile", __dir__)))
  environment = { "HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ANALYTICS" => "1" }
  warnings = 0
  [["formula", manifest.formulae, "formulae"], ["cask", manifest.casks, "casks"]].each do |kind, names, field|
    next if names.empty?
    output, errors, result = Open3.capture3(environment, "brew", "info", "--json=v2", "--#{kind}", *names.uniq)
    raise "Homebrew metadata query failed: #{errors.strip}" unless result.success?
    metadata = JSON.parse(output)
    metadata.fetch(field).each do |package|
      next unless package["deprecated"] || package["disabled"]
      name = package["full_name"] || package["token"] || package.fetch("name")
      state = package["disabled"] ? "DISABLED" : "DEPRECATED"
      reason = package["disable_reason"] || package["deprecation_reason"] || "unspecified"
      puts "#{state} #{kind} #{name}: #{reason}"
      replacement_keys = %w[disable_replacement_formula disable_replacement_cask deprecation_replacement_formula deprecation_replacement_cask]
      replacement_keys.map { |key| package[key] }.compact.uniq.each do |replacement|
        puts "  Homebrew suggests: #{replacement}"
      end
      warnings += 1
    end
  end
  puts "Audit complete: #{warnings} package warning(s). Brewfile entries and installed packages were not changed."
rescue StandardError => error
  warn "Brewfile audit failed: #{error.message}"
  exit 1
end
