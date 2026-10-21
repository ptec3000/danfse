require "test_helper"

class MunicipiosTest < Minitest::Test
  def test_known
    assert_equal "Belo Horizonte / MG", Danfse::Municipios.nome_uf("3106200")
    assert_equal "Brasília / DF", Danfse::Municipios.nome_uf(5300108)
    assert_equal "MG", Danfse::Municipios.uf("3106200")
  end

  def test_unknown_and_blank
    assert_nil Danfse::Municipios.nome_uf("9999999")
    assert_nil Danfse::Municipios.nome_uf(nil)
    assert_nil Danfse::Municipios.nome_uf("")
  end

  def test_state_accepts_integer_codes
    assert_equal "DF", Danfse::Municipios.uf(5300108)
  end

  def test_state_returns_nil_for_unknown_and_blank_codes
    ["9999999", nil, ""].each do |code|
      assert_nil Danfse::Municipios.uf(code)
    end
  end
end
