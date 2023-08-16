#include <iconv.h>
#include <boost/version.hpp>
#include <fmt/format.h>
#include <catch2/catch_test_macros.hpp>

TEST_CASE("iconv")
{
  CHECK(iconv_open("utf-8", "shift_jis"));
}

TEST_CASE("boost")
{
  CHECK(BOOST_VERSION >= 108200);
}

TEST_CASE("fmt")
{
  CHECK(fmt::format("{}", 123) == "123");
}
