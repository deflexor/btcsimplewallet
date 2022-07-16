# frozen_string_literal: true

require 'json'
require 'ostruct'
require 'logger'
require 'faraday'
require 'faraday/net_http'
Faraday.default_adapter = :net_http
require 'bitcoin'
Bitcoin.network = :testnet
require_relative './miniwallet/keyhelper'

module MiniWallet
  include Bitcoin::Builder

  module Config
    class << self
      attr_accessor :base_dir, :keys_dir, :key_file, :api_url, :tx_fee, :satoshi
    end
    self.base_dir = File.expand_path('../', __dir__)
    self.keys_dir = 'keys'
    self.key_file = 'edcsa.base58'
    self.api_url = 'https://blockstream.info/testnet/api'
    self.tx_fee = 10_000
    self.satoshi = 100_000_000
  end

  RespBalance = Struct.new(:addr, :balance)
  RespSent = Struct.new(:addr, :balance)

  class << self
    attr_accessor :logger_err, :logger
  end

  self.logger_err = Logger.new($stderr)
  self.logger = Logger.new($stdout)

  def self.balance
    key = KeyHelper.ensure_key
    response = Faraday.get("#{Config.api_url}/address/#{key.addr}")
    obj = JSON.parse(response.body, object_class: OpenStruct)
    puts obj.chain_stats.funded_txo_sum
    RespBalance.new(key.addr, obj.chain_stats.funded_txo_sum)
  end

  def self.send(amount, to)
    amount_ok = Float(amount) != nil rescue false
    raise "Amount specified incorrectly" unless amount_ok
    raise "Recipient adddress is incorrect" unless Bitcoin.valid_address? to
    key = KeyHelper.ensure_key
    response = Faraday.get("#{Config.api_url}/address/#{key.addr}/utxo")
    inputs_obj = JSON.parse(response.body, object_class: OpenStruct)
    puts response.body
    tx = new_tx(key, inputs_obj, to, amount * Config.satoshi, Config.tx_fee)
    response = send_tx tx
    puts response.status
    puts response.body
    RespSent.new(key.addr, 0)
  end

  def self.send_tx tx
    conn = Faraday.new(
      url: Config.api_url,
      headers: { 'Content-Type' => 'application/json' }
    )
    conn.post('/tx') do |req|
      req.body = tx.to_json
    end
  end

  # inputs are
  # [{txid, status: { value=satoshis, ... }}, ... ]
  def self.new_tx(key, inputs, o_addr, o_value, fee = 0)
    input_values = inputs.map(&:value).map(&:to_i)
    puts "Z"
    puts input_values
    input_value = inputs.map(&:value).map(&:to_i).inject(:+) || 0
    puts "input_val #{input_value} > #{o_value.to_i + fee}"
    raise "Insufficient funds"  unless input_value >= (o_value.to_i + fee)
    include Bitcoin::Builder
    build_tx do |t|
      t.output do |o|
        o.value value
        o.script do |s|
          s.recipient o_addr
        end
      end

      change_value = input_value - o_value - fee
      if change_value > 0
        t.output do |o|
          o.value change_value
          o.script do |s|
            s.recipient key.addr
          end
        end
      end

      inputs.each_with_index do |prev_out, idx|
        t.input do |i|
          prev_tx = prev_out.txid
          i.prev_out prev_tx
          i.prev_out_index idx
          i.signature_key key
        end
      end
    end # build tx
  end
end
