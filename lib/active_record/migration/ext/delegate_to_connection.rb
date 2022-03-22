# frozen_string_literal: true

require 'active_support/concern'

# Provides an alternate alias for `delegate` in case the one we want from Module is shadowed.
#
# Normally, you could just call delegate directly, but Migration defines this at class level,
# which shadows the delegate method from Module:
#  attr_accessor :delegate
#
module DoDelegate
  extend ActiveSupport::Concern

  module ClassMethods
    def do_delegate(*args)
      Module.instance_method(:delegate).bind_call(self, *args)
    end
  end
end

# Delegates methods directly to @connection without wrapping in say_with_time
#
# By default, to call calling on connection from a migration, it goes through
# Migration#method_missing, which wraps it in say_with_time. That can be very noisy, so you can use
# this to internal/unimportant method calls so that we only see the important output from
# change_table, for example in our migration output.
module ActiveRecord
  class Migration
    module Ext
      module DelegateToConnection
        extend ActiveSupport::Concern
        include DoDelegate

        module ClassMethods
          def delegate_to_connection(*args)
            do_delegate(*args, to: :@connection)
          end
        end
      end
    end
  end
end
