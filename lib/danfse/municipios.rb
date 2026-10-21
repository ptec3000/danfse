# frozen_string_literal: true

require "csv"

module Danfse
  module Municipios
    @mutex = Mutex.new

    def self.nome_uf(codigo)
      entry = entries[codigo.to_s]
      "#{entry[0]} / #{entry[1]}" if entry
    end

    def self.uf(codigo)
      entries[codigo.to_s]&.last
    end

    def self.entries
      @mutex.synchronize do
        @entries ||= CSV.read(ROOT.join("data/municipios.csv"), headers: true, encoding: "UTF-8").to_h do |row|
          [row.fetch("codigo").freeze, [row.fetch("nome").freeze, row.fetch("uf").freeze].freeze]
        end.freeze
      end
    end
    private_class_method :entries
  end
end
