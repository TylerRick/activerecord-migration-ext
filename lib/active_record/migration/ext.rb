# frozen_string_literal: true

require 'active_support'
require 'active_record'

require_relative 'ext/version'
require_relative 'ext/delegate_to_connection'
require_relative 'ext/command_recorder'
require_relative 'ext/change_table_move_to_end'

ActiveRecord::Migration
module ActiveRecord
  class Migration
    include Ext::DelegateToConnection
    include Ext::CommandRecorder
    include Ext::ChangeTableMoveToEnd
  end
end
