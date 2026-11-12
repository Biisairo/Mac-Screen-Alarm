.PHONY: app install test icon clean

app:
	./scripts/build-app.sh

install:
	./scripts/build-app.sh --install

test:
	swift run CoreTestRunner

icon:
	./scripts/make-icon.sh

clean:
	rm -rf .build build
