# frozen_string_literal: true

module DiscourseLlmsTxt
  class Engine < ::Rails::Engine
    engine_name DiscourseLlmsTxt::PLUGIN_NAME
    isolate_namespace DiscourseLlmsTxt
  end
end
