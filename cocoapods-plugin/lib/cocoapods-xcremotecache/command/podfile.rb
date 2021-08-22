require 'cocoapods'

module Pod
  class Podfile
    module DSL
        
      def xcremotecache(configuration)
          CocoapodsXCRemoteCacheModifier::Hooks::XCRemoteCache.configure(configuration)
      end
    end
  end
end
