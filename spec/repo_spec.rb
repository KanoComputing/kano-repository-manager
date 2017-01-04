# Tests for the Repo class
#
# Copyright (C) 2016 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

# require 'fakefs'
require 'fakefs/spec_helpers'

require 'dr/pkgversion'
require 'dr/repo'
# require 'dr/package'

# FakeFS.activate!

describe Dr do
    before(:all) do
        include FakeFS::SpecHelpers
    end

    after(:all) do
    end

    describe 'Repo' do
        describe 'repo creation' do
            it 'creates a repo' do
                Dr::Repo.new('tmp_repo')
                # expect(Dir.exists? 'tmp_repo').to be true
                # expect(Dir.exists? 'tmp_repo/packages').to be true
            end
        end
    end
end

# FakeFS.deactivate!
