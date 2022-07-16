# frozen_string_literal: true

require 'fileutils'

module MiniWallet
  module KeyHelper

    def self.ensure_key
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
      key_file = File.join(keys_dir, Config.key_file)
      if Dir.empty? keys_dir
        gen_keys(key_file: key_file)
      else
        key = File.open(key_file, 'r') { |f| Bitcoin::Key.from_base58(f.read) }
        MiniWallet.logger.info("Loaded wallet with address #{key.addr}.")
        key
      end
    end

    def self.gen_keys(key_file:)
      MiniWallet.logger.info('keys directory is empty, generating keys...')
      key = Bitcoin::Key.generate
      File.open(key_file, 'w', 0o600) { |f| f.write(key.to_base58) }
      MiniWallet.logger.info("Generated new wallet with address #{key.addr}.")
      key
    end
  end
end
