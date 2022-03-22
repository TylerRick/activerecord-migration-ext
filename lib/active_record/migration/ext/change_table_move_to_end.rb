# frozen_string_literal: true

require_relative 'command_recorder'

module ActiveRecord
  class Migration
    module Ext
      module ChangeTableMoveToEnd
        module CommandRecorder; end

        module CommandRecorder
          module Ext
            def only_add_column_commands
              dup.tap do |recorder|
                recorder.commands = commands.select do |(command, _args, _block)|
                  command == :add_column
                end
              end
            end

            def filter_add_column_commands
              dup.tap do |recorder|
                recorder.commands = commands.map do |(command, args, block)|
                  if command == :add_column
                    yield [command, args, block]
                  else
                    [command, args, block]
                  end
                end
              end
            end

            def column_names
              only_add_column_commands.commands.map do |(_command, args, _block)|
                _table_name, name, _type = args
                name
              end
            end

            def add_suffix(suffix)
              only_add_column_commands.tap do |recorder|
                recorder.commands = commands.map do |(command, args, _block)|
                  table_name, name, type = args
                  name = "#{name}#{suffix}"
                  [command, [table_name, name, type]]
                end
              end
            end

            # changes add_column to rename_column, asking the provided block to transform the name
            def change_add_column_to_rename
              only_add_column_commands.tap do |recorder|
                recorder.commands = commands.map do |(_command, args, _block)|
                  table_name, name, _type = args
                  [:rename_column, [table_name, name, yield(name)]]
                end
              end
            end
          end
        end

        # Provides a convenient way to reorder your columns, since you can't use after: 'other_field' when using PostgreSQL
        # (https://dba.stackexchange.com/questions/3276/how-can-i-specify-the-position-for-a-new-column-in-postgresql)
        #
        # Adds a new copy of the given columns, copies data into the new columns, then removes the old
        # columns, and renames the new columns to the original names.
        #
        # Does not re-add indexes.
        #
        def change_table_move_to_end(table_name, &block)
          add_orig_columns = recorder_record do
            change_table table_name, &block
          end
          add_orig_columns.extend(CommandRecorder::Ext)
          # pp add_orig_columns.commands

          say_with_time_and_silence "Moving to end of #{table_name}: #{add_orig_columns.column_names.join(', ')}" do
            # Add a new copy of the given columns (with temporary names)
            add_new_columns = add_orig_columns.add_suffix('_copy').extend(CommandRecorder::Ext)
            # pp add_new_columns.commands
            add_new_columns.replay(self)

            # Copy data into the new columns
            column_names_to_temp_names = add_orig_columns.column_names.map do |name|
              [name, "#{name}_copy"]
            end
            reversible do |dir|
              dir.up do
                execute <<~END
                  update #{table_name}
                    set
                      #{column_names_to_temp_names.map do |orig, temp|
                        "#{temp} = #{orig}"
                      end.join(",\n")}
                    ;
                END
              end
              dir.down do
                execute <<~END
                  update #{table_name}
                    set
                      #{column_names_to_temp_names.map do |orig, temp|
                        "#{orig} = #{temp}"
                      end.join(",\n")}
                    ;
                END
              end
            end

            # Remove the old columns
            # pp add_orig_columns.inverse.commands
            add_orig_columns.inverse.replay(self)

            # Rename the new columns to the original names.
            add_new_columns.change_add_column_to_rename do |name|
              name.sub(/_copy$/, '')
            end.replay(self)
          end
        end

        def say_with_time_and_silence(message, &block)
          say_with_time message do
            suppress_messages(&block)
          end
        end
      end
    end
  end
end
