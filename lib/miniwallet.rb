# frozen_string_literal: true

require 'logger'
require_relative './miniwallet/keyhelper'

module MiniWallet
  module Config
    class << self
      attr_accessor :base_dir, :keys_dir, :private_key_file, :public_key_file
    end
    self.base_dir = File.expand_path('../', __dir__)
    self.keys_dir = 'keys'
    self.public_key_file = 'edcsa.pub'
    self.private_key_file = 'edcsa'
  end

  class << self
    attr_accessor :logger_err, :logger
  end

  self.logger_err = Logger.new($stderr)
  self.logger = Logger.new($stdout)

  # class App
  #   def initialize
  #     @config = Config.new
  #   end

  #   def configure
  #     return unless block_given?

  #     yield @config
  #   end
  # end

  # @@app = App.new
  # def self.application
  #   @@app
  # end

  def self.balance
    KeyHelper.ensure_keys
  end
end
