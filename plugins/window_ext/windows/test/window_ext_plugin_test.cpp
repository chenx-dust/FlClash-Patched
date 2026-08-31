#include <gtest/gtest.h>

#include "window_ext_plugin.h"

namespace window_ext {
namespace test {

TEST(WindowExtPlugin, MatchesOnlyRegisteredActivationMessage) {
  EXPECT_TRUE(WindowExtPlugin::IsActivationMessage(42, 42));
  EXPECT_FALSE(WindowExtPlugin::IsActivationMessage(41, 42));
  EXPECT_FALSE(WindowExtPlugin::IsActivationMessage(0, 0));
}

}  // namespace test
}  // namespace window_ext
