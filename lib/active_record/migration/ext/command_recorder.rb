# frozen_string_literal: true

module ActiveRecord
  class Migration
    module Ext
      module CommandRecorder
        # ActiveRecord::Migration#revert automatically calls recorder.replay(self) and doesn't even return
        # the recorder; this returns the recorder, letting you to do whatever you want with it.
        #
        # AKA revert_without_replay
        #
        #   recorder = recorder_revert do
        #     change_table 'users' do |t|
        #       t.string 'name'
        #       t.integer 'number'
        #     end
        #   end
        #   pp recorder.commands
        #   # =>  [[:remove_column, ["users", "number", :integer], nil], [:remove_column, ["users", "name", :string], nil]]
        #   pp recorder.inverse.commands
        #   # => [[:add_column, ["users", "name", :string], nil], [:add_column, ["users", "number", :integer], nil]]
        #
        def recorder_revert(*_migration_classes, &block)
          command_recorder.tap do |recorder|
            @connection = recorder
            suppress_messages do
              connection.revert(&block)
            end
            @connection = recorder.delegate
            # recorder.replay(self)
          end
        end

        # Records commands returns the recorder.
        #
        #   recorder = recorder_record do
        #     change_table 'users' do |t|
        #       t.string 'name'
        #       t.integer 'number'
        #     end
        #   end
        #   pp recorder.commands
        #   # => [[:add_column, ["users", "name", :string], nil], [:add_column, ["users", "number", :integer], nil]]
        #   pp recorder.inverse.commands
        #   # =>  [[:remove_column, ["users", "number", :integer], nil], [:remove_column, ["users", "name", :string], nil]]
        #
        # Based on recorder_revert but without the revert
        def recorder_record(&block)
          command_recorder.tap do |recorder|
            @connection = recorder
            suppress_messages(&block)
            @connection = recorder.delegate
            # recorder.replay(self)
          end
        end
      end
    end
  end
end

module ActiveRecord
  class Migration
    class CommandRecorder
      def dup
        CommandRecorder.new(delegate).tap do |recorder|
          recorder.commands = commands
        end
      end

      # Returns the inverse of these commands — the same as if they had been recorded with revert:
      # each command is reverted and in the reverse order.
      def inverse
        dup.tap do |recorder|
          recorder.commands = commands.reverse.map do |(command, args, _block)|
            inverse_of(command, args)
          end
        end
      end
    end
  end
end
