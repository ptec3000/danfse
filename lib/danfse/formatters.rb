# frozen_string_literal: true

require "bigdecimal"
require "date"

module Danfse
  module Formatters
    module_function

    def documento(cnpj: nil, cpf: nil, nif: nil)
      unless missing?(cnpj)
        return cnpj.to_s.upcase.sub(/\A([A-Z0-9]{2})([A-Z0-9]{3})([A-Z0-9]{3})([A-Z0-9]{4})(\d{2})\z/, '\1.\2.\3/\4-\5')
      end
      unless missing?(cpf)
        return cpf.to_s.sub(/\A(\d{3})(\d{3})(\d{3})(\d{2})\z/, '\1.\2.\3-\4')
      end

      missing?(nif) ? "-" : nif.to_s
    end

    def cep(value)
      return "-" if missing?(value)

      value.to_s.sub(/\A(\d{2})(\d{3})(\d{3})\z/, '\1.\2-\3')
    end

    def data(value)
      return "-" if missing?(value)

      Date.iso8601(value.to_s).strftime("%d/%m/%Y")
    rescue ArgumentError => error
      raise InvalidXml, "Data inválida: #{error.message}"
    end

    def data_hora(value)
      return "-" if missing?(value)

      DateTime.iso8601(value.to_s).strftime("%d/%m/%Y %H:%M:%S")
    rescue ArgumentError => error
      raise InvalidXml, "Data e hora inválidas: #{error.message}"
    end

    def moeda(value)
      return "-" if missing?(value)

      "R$ #{decimal_string(value, thousands: true)}"
    end

    def percentual(value)
      return "-" if missing?(value)

      "#{decimal_string(value)}%"
    end

    def codigo_tributacao(national, municipal = nil)
      return "-" if missing?(national)

      code = national.to_s.sub(/\A(\d{2})(\d{2})(\d{2})\z/, '\1.\2.\3')
      missing?(municipal) ? code : "#{code} / #{municipal}"
    end

    def nbs(value)
      return "-" if missing?(value)

      value.to_s.sub(/\A(\d)(\d{4})(\d{2})(\d{2})\z/, '\1.\2.\3.\4')
    end

    def truncar(text, threshold)
      return "-" if missing?(text)

      text = text.to_s
      text.length > threshold ? "#{text[0, threshold]}..." : text
    end

    def missing?(value)
      value.nil? || value.to_s.empty?
    end
    private_class_method :missing?

    def decimal_string(value, thousands: false)
      rounded = BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      rounded = rounded.abs if rounded.zero?
      integer, fraction = rounded.to_s("F").split(".", 2)
      integer = integer.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1.') if thousands
      "#{integer},#{fraction.ljust(2, '0')}"
    end
    private_class_method :decimal_string
  end
end
