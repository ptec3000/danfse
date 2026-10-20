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

  def test_assets_exist
    assert Danfse::FONT_DIR.join("LiberationSans-Regular.ttf").exist?
    assert Danfse::FONT_DIR.join("LiberationSans-Bold.ttf").exist?
    assert Danfse::LOGO_PATH.exist?
  end

  def test_name_and_state_accept_integer_and_string_codes
    assert_equal "Belo Horizonte", Danfse::Municipios.nome("3106200")
    assert_equal "Brasília", Danfse::Municipios.nome(5300108)
    assert_equal "DF", Danfse::Municipios.uf(5300108)
  end

  def test_name_and_state_return_nil_for_unknown_and_blank_codes
    ["9999999", nil, ""].each do |code|
      assert_nil Danfse::Municipios.nome(code)
      assert_nil Danfse::Municipios.uf(code)
    end
  end
end
