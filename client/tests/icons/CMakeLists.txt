cmake_minimum_required(VERSION 3.25)
project(PaintedIconTests LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
enable_testing()
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Svg Test)
add_executable(painted-icon-tests tst_paintedIcon.cpp
    ../../ui/utils/paintedIcon.cpp ../../ui/utils/paintedIcon.h ../../ui/utils/pageEnum.h)
target_link_libraries(painted-icon-tests PRIVATE Qt6::Quick Qt6::Svg Qt6::Test)
target_compile_definitions(painted-icon-tests PRIVATE CLIENT_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../..")
qt_add_resources(painted-icon-tests icons PREFIX "/images/controls"
    BASE "../../images/controls"
    FILES "../../images/controls/home.svg" "../../images/controls/settings.svg"
          "../../images/controls/chevron-down.svg" "../../images/controls/check.svg")
add_test(NAME painted-icons COMMAND painted-icon-tests)
set_tests_properties(painted-icons PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Basic")
