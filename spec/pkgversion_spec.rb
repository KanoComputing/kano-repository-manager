# Tests for the PkgVersion class
#
# Copyright (C) 2015 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU GPL v2

require 'dr/pkgversion'

describe Dr do
  describe 'PkgVersion' do
    describe "compare based on epoch" do
      it "works when smaller" do
        one = Dr::PkgVersion.new('1:1.5-1')
        two = Dr::PkgVersion.new('2:1.5-1')

        expect(one < two).to be_true
      end

      it "works when equal" do
        one = Dr::PkgVersion.new('1:2.7-2')
        two = Dr::PkgVersion.new('1:2.7-2')

        expect(one == two).to be_true
      end

      it "works when smaller" do
        one = Dr::PkgVersion.new('2:3.6-1')
        two = Dr::PkgVersion.new('1:3.5')

        expect(one > two).to be_true
      end
    end

    describe "compare based on upstram version" do
      it "works when epoch is equal" do
        one = Dr::PkgVersion.new('1:1.5-1')
        two = Dr::PkgVersion.new('1:1.6-1')

        expect(one < two).to be_true
      end

      it "works when smaller" do
        one = Dr::PkgVersion.new('1-1')
        two = Dr::PkgVersion.new('2')

        expect(one < two).to be_true
      end

      it "works when smaller with string inbetween" do
        one = Dr::PkgVersion.new('1.5')
        two = Dr::PkgVersion.new('1.16-5')

        expect(one < two).to be_true
      end

      it "works when equal" do
        one = Dr::PkgVersion.new('1.5-5')
        two = Dr::PkgVersion.new('1.5-5')

        expect(one == two).to be_true
      end

      it "equal with no debian version" do
        one = Dr::PkgVersion.new('15')
        two = Dr::PkgVersion.new('15')

        expect(one == two).to be_true
      end

      it "works when bigger" do
        one = Dr::PkgVersion.new('6.5')
        two = Dr::PkgVersion.new('1.16-5')

        expect(one > two).to be_true
      end
    end

    describe "compare based on debian version" do
      it "smaller comparison" do
        one = Dr::PkgVersion.new('1.5-1')
        two = Dr::PkgVersion.new('1.5-2')

        expect(one < two).to be_true
      end

      it "equal comparison" do
        one = Dr::PkgVersion.new('1.5-2')
        two = Dr::PkgVersion.new('1.5-2')

        expect(one == two).to be_true
      end

      it "bigger comparison" do
        one = Dr::PkgVersion.new('1.5-11')
        two = Dr::PkgVersion.new('1.5-9')

        expect(one > two).to be_true
      end

      it "substring comparison" do
        one = Dr::PkgVersion.new('1.5-111')
        two = Dr::PkgVersion.new('1.5-11')

        expect(one > two).to be_true
      end
    end

    describe "build tags" do
      it "build date parsed correctly" do
        v = Dr::PkgVersion.new('1.5-1.20150323')
        expect(v.date).to eq 20150323
      end

      it "build number parsed correctly" do
        v = Dr::PkgVersion.new('1.5-1.20150323build9')
        expect(v.build).to eq 9
      end

      it "debian version parsed correctly with build tag" do
        v = Dr::PkgVersion.new('1.5-7.20150323build9')
        expect(v.debian).to eq "7"
      end

      it "debian version includes malformed build tag" do
        v = Dr::PkgVersion.new('1.5-7.a20150323build9')
        expect(v.debian).to eq "7.a20150323build9"
      end
    end

    describe "comparison with build tags" do
      it "smaller date" do
        one = Dr::PkgVersion.new('1.5-7.20150320')
        two = Dr::PkgVersion.new('1.5-7.20150323')

        expect(one < two).to be_true
      end

      it "bigger date" do
        one = Dr::PkgVersion.new('1.5-7.20150328')
        two = Dr::PkgVersion.new('1.5-7.20150323')

        expect(one > two).to be_true
      end

      it "equal dates" do
        one = Dr::PkgVersion.new('1.5-7.20150328')
        two = Dr::PkgVersion.new('1.5-7.20150328')

        expect(one == two).to be_true
      end

      it "equal dates with build numbers (smaller)" do
        one = Dr::PkgVersion.new('1.5-7.20150328build1')
        two = Dr::PkgVersion.new('1.5-7.20150328build5')

        expect(one < two).to be_true
      end

      it "equal dates with build numbers (equal)" do
        one = Dr::PkgVersion.new('1.5-7.20150328build15')
        two = Dr::PkgVersion.new('1.5-7.20150328build15')

        expect(one == two).to be_true
      end

      it "equal dates with build numbers (bigger)" do
        one = Dr::PkgVersion.new('1.5-7.20150328build15')
        two = Dr::PkgVersion.new('1.5-7.20150328build5')

        expect(one > two).to be_true
      end

      it "build number substrings" do
        one = Dr::PkgVersion.new('1.5-7.20150328build11')
        two = Dr::PkgVersion.new('1.5-7.20150328build111')

        expect(one < two).to be_true
      end
    end
  end
end
