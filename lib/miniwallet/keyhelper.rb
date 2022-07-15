# frozen_string_literal: true

require 'fileutils'
require 'openssl'
require 'base64'

module MiniWallet
  module KeyHelper

    def self.ensure_keys
      check_keys_dir
      check_keys
    rescue => err
      MiniWallet.logger.fatal(err)
      raise
    end

    # Check whether keys dir exists and create one if not
    def self.check_keys_dir
      keys_dir = File.join(Config.base_dir, Config.keys_dir)
      unless Dir.exist? keys_dir
        MiniWallet.logger.info("keys directory doesn't exist, creating one...")
        FileUtils.mkdir keys_dir, mode: 0o700
      end
    end

    # Check whether keys are in place or generate ones
    def self.check_keys
      keys_dir = File.join(Config.base_dir, Config.keys_dir)
      if Dir.empty? keys_dir
        private_key_file = File.join(keys_dir, Config.private_key_file)
        public_key_file = File.join(keys_dir, Config.public_key_file)
        gen_keys_in_dir(
          keys_dir: keys_dir,
          private_key_file: private_key_file,
          public_key_file: public_key_file)
      end
    end

    def self.gen_keys_in_dir(keys_dir:, private_key_file:, public_key_file:)
      MiniWallet.logger.info('keys directory is empty, generating keys...')
      key = OpenSSL::PKey::EC.new('secp256k1')
      key.generate_key
      public_key = key.public_key
      public_key_hex = public_key.to_bn.to_s(16).downcase # public key in hex format
      private_key = key.private_key
      private_key_hex = private_key.to_s(16).downcase
      File.open(private_key_file, 'w', 0o400) { |f| f.write(private_key_hex) }
      File.open(public_key_file, 'w', 0o600) { |f| f.write(public_key_hex) }
      MiniWallet.logger.info('done.')
    end
  end
end
