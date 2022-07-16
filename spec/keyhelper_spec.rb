require 'fileutils'
require_relative '../lib/miniwallet'

RSpec.describe "KeyHelper" do
    context "gen_keys_in_dir" do


        before :all do
            @keys_dir = File.join( __dir__, 'keys')
            @key_file = File.join(@keys_dir, MiniWallet::Config.key_file)
            FileUtils.rmtree @keys_dir
            FileUtils.mkdir @keys_dir, mode: 0o700
        end
        
        after :all do
            FileUtils.rmtree @keys_dir
        end

        it "generates keys in directory" do

            MiniWallet::KeyHelper.gen_keys(key_file: @key_file)
            expect(File.exist?(@key_file)).to be_truthy
        end

    end
end