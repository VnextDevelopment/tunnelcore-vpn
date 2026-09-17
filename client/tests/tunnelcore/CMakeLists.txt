cmake_minimum_required(VERSION 3.25)
project(TunnelCoreControllerTests LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
enable_testing()
find_package(Qt6 REQUIRED COMPONENTS Core Network Test)
add_executable(tunnelcore-controller-tests
    tst_tunnelCoreController.cpp
    ../../ui/controllers/tunnelCoreController.cpp
    ../../ui/controllers/tunnelCoreController.h)
target_link_libraries(tunnelcore-controller-tests PRIVATE Qt6::Core Qt6::Network Qt6::Test)
add_test(NAME tunnelcore-controller COMMAND tunnelcore-controller-tests)
