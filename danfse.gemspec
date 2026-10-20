require_relative "lib/danfse/version"

Gem::Specification.new do |spec|
  spec.name = "danfse"
  spec.version = Danfse::VERSION
  spec.authors = ["Acervo Tecnologia"]
  spec.summary = "Gera o PDF do DANFSe (NFS-e Nacional, NT 008/2026) a partir do XML autorizado"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*", "assets/**/*", "data/**/*", "exe/*", "LICENSE", "README.md"].select { |path| File.file?(path) }
  spec.bindir = "exe"
  spec.executables = ["danfse"]

  spec.add_dependency "prawn", "~> 2.5"
  spec.add_dependency "rqrcode", "~> 3.0"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "bigdecimal"
end
