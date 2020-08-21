# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "indrarahul-codes"
  spec.version       = "1.0.3"
  spec.authors       = ["Rahul Indra"]
  spec.email         = ["indrarahul2013@gmail.com"]

  spec.summary       = "Google Summer of Code 2020"
  spec.homepage      = "https://github.com/indrarahul2013/CMSMonitoring"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").select { |f| f.match(%r!^(assets|_layouts|_includes|_sass|LICENSE|README)!i) }

  spec.add_runtime_dependency "jekyll", "~> 4.0"
  spec.add_runtime_dependency "jekyll-paginate", "~> 1.1.0"
  spec.add_runtime_dependency "jekyll-seo-tag", "~> 2.6.1"
  spec.add_runtime_dependency "jekyll-feed", "~> 0.13.0"  
  spec.add_runtime_dependency "jekyll-sitemap", "~> 1.4.0"
  
  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "rake", "~> 12.0"
end