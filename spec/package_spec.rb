# Tests for the Package class
#
# Copyright (C) 2016 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

# require 'fakefs'
require 'fakefs/spec_helpers'

require 'dr/pkgversion'
require 'dr/repo'
require 'dr/package'


describe Dr do

  before(:all) do
    include FakeFS::SpecHelpers
    FakeFS.activate!

    @repo = Dr::Repo.new('tmp_repo')

    @pkg_name = 'test'
    @pkg = Dr::Package.new(@pkg_name, @repo)

    @pkg_versions = [
      '2.10-0.20161116',
      '2.9-0.20160603'
    ]
    @pkg_builds = @pkg_versions.collect { |version|
      "#{@pkg_name}_#{version}"
    }

    @missing_pkg_versions = [
      '2.12-0.20161116',
      '2.9-1.20160603'
    ]
    @missing_pkg_builds = @missing_pkg_versions.collect { |version|
      "#{@pkg_name}_#{version}"
    }

    @pkg_build_dir = "#{@repo.location}/packages/#{@pkg_name}/builds/"
    FileUtils.mkdir_p @pkg_build_dir

    @pkg_builds.each do |build|
      FileUtils.mkdir_p "#{@pkg_build_dir}/#{build}"
    end
  end


  after(:all) do
    FakeFS.deactivate!
  end


  describe 'Package' do
    describe 'list builds' do
      it 'correctly lists packages' do
        expect(@pkg.history).to eq(@pkg_builds.sort.reverse)
      end
    end


    describe 'build exists' do
      it 'correctly determines that builds exist' do
          @pkg_builds.each do |version|
            expect(@pkg.build_exists? version).to be true
          end
      end

      it 'correctly determines that builds don\'t exist' do
          @missing_pkg_builds.each do |version|
            expect(@pkg.build_exists? version).to be false
          end
      end
    end


    describe 'remove build' do
      # def remove_build(version)
    end


    describe 'get configuration' do
      # def get_configuration
    end


    describe 'set configuration' do
      # def set_configuration(config)
    end


    describe '<=>' do
      # def <=>(o)
    end

  end
end
