require 'fileutils'
require_relative '../lib/miniwallet'

RSpec.describe "KeyHelper" do
    context "gen_keys_in_dir" do


        before :all do
            @keys_dir = File.join( __dir__, 'keys')
            @private_key_file = File.join(@keys_dir, MiniWallet::Config.private_key_file)
            @public_key_file = File.join(@keys_dir, MiniWallet::Config.public_key_file)
            FileUtils.rmtree @keys_dir
            FileUtils.mkdir @keys_dir, mode: 0o700
        end
        
        after :all do
            FileUtils.rmtree @keys_dir
        end

        it "generates keys in directory" do

            MiniWallet::KeyHelper.gen_keys_in_dir(
                keys_dir: @keys_dir,
                private_key_file: @private_key_file,
                public_key_file: @public_key_file)
            expect(File.exist?(@private_key_file)).to be_truthy
            expect(File.exist?(@public_key_file)).to be_truthy
        end

    end
end