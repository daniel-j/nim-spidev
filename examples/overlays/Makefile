.PHONY: all clean

all: blinkt.dtbo

clean:
	rm *.dtbo

%.dtbo: %-overlay.dts
	dtc -@ -O dtb -o "$@" "$^"

uninstall-%:
	sudo dtoverlay -r "$*"

install-%: %.dtbo
	sudo dtoverlay -d . "$*"

