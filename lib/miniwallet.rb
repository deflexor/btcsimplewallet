# frozen_string_literal: true

require 'json'
require 'ostruct'
require 'logger'
require 'stringio'
require 'faraday'
require 'faraday/net_http'
Faraday.default_adapter = :net_http
require 'bitcoin'
Bitcoin.network = :testnet
require_relative './miniwallet/keyhelper'

module MiniWallet

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
    response = Faraday.get("#{Config.api_url}/address/#{key.addr}/utxo")
    inputs_obj = JSON.parse(response.body, object_class: OpenStruct)
    bal = inputs_obj.map(&:value).map(&:to_i).inject(:+) || 0
    RespBalance.new(key.addr, bal)
  end

  def self.send(amount, to)
    amount_ok = Float(amount) != nil rescue false
    raise "Amount specified incorrectly" unless amount_ok
    raise "Recipient adddress is incorrect" unless Bitcoin.valid_address? to
    key = KeyHelper.ensure_key
    response = Faraday.get("#{Config.api_url}/address/#{key.addr}/utxo")
    inputs_obj = JSON.parse(response.body, object_class: OpenStruct)
    tx = new_tx(key, inputs_obj, to, amount * Config.satoshi, Config.tx_fee)
    send_tx tx
  end

  def self.send_tx tx
    conn = Faraday.new(url: Config.api_url, headers: {'Content-Type' => 'text/plain'})
    resp = conn.post('/testnet/api/tx') do |req|
      req.body = tx.to_payload.unpack('H*')[0]
    end
    if resp.status != 200
      raise "Sending tx failed: #{resp.status} #{resp.headers} #{resp.body}"
    else
      resp.body
    end
  end

  # inputs are
  # [{txid, value=satoshis }, ... ]
  def self.new_tx(key, inputs, o_addr, o_value, fee = 0)
    input_value = inputs.map(&:value).map(&:to_i).inject(:+) || 0
    raise "Insufficien  t funds"  unless input_value >= (o_value.to_i + fee)
    tx = Bitcoin::Protocol::Tx.new
    tx.add_out Bitcoin::Protocol::TxOut.value_to_address(o_value.to_i, o_addr)
    change_value = input_value - o_value.to_i - fee
    tx.add_out Bitcoin::Protocol::TxOut.value_to_address(change_value, key.addr) if change_value > 0

    inputs.each_with_index do |prev_out, idx|
      prev_tx_bin = Faraday.get("#{Config.api_url}/tx/#{prev_out.txid}/raw").body
      prev_tx = Bitcoin::Protocol::Tx.new(prev_tx_bin)
      tx.add_in Bitcoin::Protocol::TxIn.new(prev_tx.binary_hash, idx, 0)
      # signing inputs.
      sig = key.sign(tx.signature_hash_for_input(0, prev_tx))
      tx.in[idx].add_signature_pubkey_script(sig, key.pub)
    end
    tx
  end

end
