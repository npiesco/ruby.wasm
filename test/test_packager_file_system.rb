require "test-unit"
require "tmpdir"
require "bundler"
require "ruby_wasm"

class TestPackagerFileSystem < Test::Unit::TestCase
  def test_path_gem_directory_entries_merge_without_nesting
    Dir.mktmpdir do |dir|
      gem_dir = File.join(dir, "example")
      lib_dir = File.join(gem_dir, "lib", "example", "config")
      FileUtils.mkdir_p(lib_dir)
      File.write(File.join(lib_dir, "value.rb"), "module Example; Value = :ok; end\n")
      File.symlink("value.rb", File.join(lib_dir, "current.rb"))
      File.write(
        File.join(gem_dir, "example.gemspec"),
        <<~GEMSPEC
          Gem::Specification.new do |spec|
            spec.name = "example"
            spec.version = "0.1.0"
            spec.summary = "path packaging regression"
            spec.authors = ["ruby.wasm"]
            spec.files = [
              "lib/example",
              "lib/example/config",
              "lib/example/config/current.rb",
              "lib/example/config/value.rb"
            ]
            spec.require_paths = ["lib"]
          end
        GEMSPEC
      )

      gemfile = File.join(dir, "Gemfile")
      File.write(
        gemfile,
        <<~GEMFILE
          source "https://rubygems.org"
          gem "example", path: "example"
        GEMFILE
      )

      definition = Bundler::Definition.build(gemfile, nil, nil)
      packager = RubyWasm::Packager.new(dir, nil, definition)
      destination = File.join(dir, "packaged")
      FileUtils.mkdir_p(destination)
      RubyWasm::Packager::FileSystem.new(destination, packager).package_gems

      packaged_gem = File.join(destination, "bundle", "gems", "example-0.1.0")
      assert_path_exist(File.join(packaged_gem, "lib", "example", "config", "value.rb"))
      packaged_link = File.join(packaged_gem, "lib", "example", "config", "current.rb")
      assert_true(File.symlink?(packaged_link))
      assert_equal("value.rb", File.readlink(packaged_link))
      assert_path_not_exist(File.join(packaged_gem, "lib", "example", "config", "config"))
    end
  end
end
