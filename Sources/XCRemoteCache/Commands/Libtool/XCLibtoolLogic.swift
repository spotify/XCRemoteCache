/// XCLibtool wrapper logic that executes the libtool logic
protocol XCLibtoolLogic {
    /// Executes xclibtool mocked logic or fallbacks to the libtool execution
    func run()
}

extension XCCreateBinary: XCLibtoolLogic {}
