# TODO: REMOVE IN 2.2.
module Trailblazer
  module Operation::Railway
    module DSL
      # Allows old macros with the `(input, options)` signature.
      module DeprecatedMacro
        def build_task_for_macro(step:raise, **args)
          proc, default_options, runner_options = *step

          if proc.is_a?(Proc)
            return super if proc.arity != 2
          else
            return super if proc.method(:call).arity != 2
          end

          warn %{[Trailblazer] Macros with API (input, options) are deprecated. Please use the "Task API" signature (direction, options, flow_options). (#{proc})}

          __proc = ->(direction, options, flow_options) do
            result    = proc.(flow_options[:exec_context], options) # run the macro, with the deprecated signature.
            direction = TaskBuilder.binary_direction_for(result, Circuit::Right, Circuit::Left)

            [ direction, options, flow_options ]
          end

          super(args.merge( step: [__proc, default_options, runner_options] ))
        end
      end # DeprecatedMacro
    end
  end
end
