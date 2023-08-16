all:
	cmake -G Ninja -B build -S .
	cmake --build build

.PHONY: test
test:
	(cd build; ctest)
