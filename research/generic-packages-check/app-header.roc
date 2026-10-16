app [main!] { header: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst" }

import header.Header
import header.Imports
import header.PackageUrl

main! = |_args| Ok({})

expect {
	url = PackageUrl.parse("https://github.com/roc-lang/unicode/releases/download/4.2.0/4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w.tar.zst")?
	url.group() == { form: "github.com/roc-lang/unicode/releases/download/{v}/", series: "4" }
}

expect {
	text = "app [main!] { pf: platform \"https://example.com/1.0.0/abc.tar.zst\" }\n"
	edited = Header.set_value(text, "pf", "https://example.com/1.1.0/def.tar.zst")?
	edited == "app [main!] { pf: platform \"https://example.com/1.1.0/def.tar.zst\" }\n"
}

expect Imports.scan("import pf.Stdout\nimport Geo\n").map(|i| i.name) == ["Stdout", "Geo"]
