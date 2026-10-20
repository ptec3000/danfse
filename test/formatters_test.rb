require "test_helper"

class FormattersTest < Minitest::Test
  def test_documento
    assert_equal "51.944.463/0001-42", Danfse::Formatters.documento(cnpj: "51944463000142")
    assert_equal "123.456.789-01", Danfse::Formatters.documento(cpf: "12345678901")
    assert_equal "AB123", Danfse::Formatters.documento(nif: "AB123")
    assert_equal "-", Danfse::Formatters.documento
    assert_equal "AB123", Danfse::Formatters.documento(cnpj: "", cpf: "", nif: "AB123")
    assert_equal "51.944.463/0001-42", Danfse::Formatters.documento(cnpj: "51944463000142", cpf: "12345678901")
  end

  def test_moeda
    assert_equal "R$ 1.234,50", Danfse::Formatters.moeda("1234.5")
    assert_equal "R$ 0,01", Danfse::Formatters.moeda("0.01")
    assert_equal "R$ 0,00", Danfse::Formatters.moeda("0")
    assert_equal "R$ -1.234,57", Danfse::Formatters.moeda("-1234.565")
    assert_equal "R$ 10.000.000.000.000.000,01", Danfse::Formatters.moeda("10000000000000000.01")
    assert_equal "R$ 1,01", Danfse::Formatters.moeda("1.005")
  end

  def test_percentual
    assert_equal "0,65%", Danfse::Formatters.percentual("0.65")
    assert_equal "2,00%", Danfse::Formatters.percentual("2")
    assert_equal "0,00%", Danfse::Formatters.percentual("0")
    assert_equal "1,01%", Danfse::Formatters.percentual("1.005")
  end

  def test_datas_preserve_the_xml_local_time
    assert_equal "20/10/2026", Danfse::Formatters.data("2026-10-20")
    assert_equal "20/10/2026 18:55:01", Danfse::Formatters.data_hora("2026-10-20T18:55:01-03:00")
    assert_equal "20/10/2026 00:15:01", Danfse::Formatters.data_hora("2026-10-20T00:15:01+14:00")
    assert_equal "20/10/2026 23:55:01", Danfse::Formatters.data_hora("2026-10-20T23:55:01-12:00")
  end

  def test_codigos
    assert_equal "01.05.01 / 001", Danfse::Formatters.codigo_tributacao("010501", "001")
    assert_equal "99.01.01", Danfse::Formatters.codigo_tributacao("990101", nil)
    assert_equal "01.05.01", Danfse::Formatters.codigo_tributacao("010501", "")
    assert_equal "1.1103.22.00", Danfse::Formatters.nbs("111032200")
    assert_equal "30.140-138", Danfse::Formatters.cep("30140138")
  end

  def test_truncar_preserves_the_first_gatilho_characters
    assert_equal "abcdefg...", Danfse::Formatters.truncar("abcdefghij", 7)
    assert_equal "abc", Danfse::Formatters.truncar("abc", 7)
    assert_equal "abcdefg", Danfse::Formatters.truncar("abcdefg", 7)
    assert_equal "ação...", Danfse::Formatters.truncar("ação longa", 4)
    [37, 77, 167, 1297, 1997].each do |threshold|
      assert_equal ("a" * threshold) + "...", Danfse::Formatters.truncar("a" * (threshold + 1), threshold)
      assert_equal "a" * threshold, Danfse::Formatters.truncar("a" * threshold, threshold)
    end
  end

  def test_missing_values_are_dashes
    [nil, ""].each do |missing|
      [:cep, :data, :data_hora, :moeda, :percentual, :nbs].each do |method|
        assert_equal "-", Danfse::Formatters.public_send(method, missing)
      end
      assert_equal "-", Danfse::Formatters.documento(cnpj: missing, cpf: missing, nif: missing)
      assert_equal "-", Danfse::Formatters.codigo_tributacao(missing, "001")
      assert_equal "-", Danfse::Formatters.truncar(missing, 7)
    end
  end
end
