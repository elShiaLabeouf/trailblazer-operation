module Trailblazer
  module Operation::Railway
    # WARNING: The API here is still in a state of flux since we want to provide a simple yet flexible solution.
    # This is code run at compile-time and can be slow.
    module DSL
      def pass(proc, options={}); add_step!(:pass, proc, options); end
      def fail(proc, options={}); add_step!(:fail, proc, options); end
      def step(proc, options={}); add_step!(:step, proc, options); end
      alias_method :success, :pass
      alias_method :failure, :fail

      private
      StepArgs = Struct.new(:original_args, :incoming_direction, :connections, :args_for_Step, :insert_before)

      # Override these if you want to extend how tasks are built.
      def args_for_pass(activity, *args); StepArgs.new( args, Circuit::Right, [], [Circuit::Right, Circuit::Right], activity[:End, :right] ); end
      def args_for_fail(activity, *args); StepArgs.new( args, Circuit::Left,  [], [Circuit::Left, Circuit::Left], activity[:End, :left] ); end
      def args_for_step(activity, *args); StepArgs.new( args, Circuit::Right, [[ Circuit::Left, activity[:End, :left] ]], [Circuit::Right, Circuit::Left], activity[:End, :right] ); end

      def add_step!(type, proc, options)
        heritage.record(type, proc, options)

        activity, sequence = self["__activity__"], self["__sequence__"]

        # compile the arguments specific to step/fail/pass.
        args_for = send("args_for_#{type}", activity, proc, options)

        self["__activity__"] = add(activity, sequence, args_for )
      end

      # @api private
      # 1. Processes the step API's options (such as `:override` of `:before`).
      # 2. Uses `Sequence.alter!` to maintain a linear array representation of the circuit's tasks.
      #    This is then transformed into a circuit/Activity. (We could save this step with some graph magic)
      # 3. Returns a new Activity instance.
      def add(activity, sequence, step_args, step_builder=Operation::Railway::Step) # decoupled from any self deps.
        proc, user_options = *step_args.original_args

        macro = proc.is_a?(Array)

        if macro
          proc, default_options, runner_options = *proc
        else
          proc, default_options = proc, { name: proc }
        end

        proc, options = process_args(proc, default_options, user_options)

        if macro
          task = build_task_for_macro(proc, options, step_args, step_builder)
        else
          # Wrap step code into the actual circuit task.
          task = build_task_for_step(proc, options, step_args, step_builder)
        end

        # 1. insert Step into Sequence (append, replace, before, etc.)
        sequence.insert!(task, options, step_args)
        # 2. transform sequence to Activity
        sequence.to_activity(activity)
        # 3. save Activity in operation (on the outside)
      end

      private
      # DSL option processing: proc/macro, :override
      def process_args(proc, default_options, user_options)
        options = default_options.merge(user_options)
        options = options.merge(replace: options[:name]) if options[:override] # :override

        [ proc, options ]
      end

      def build_task_for_step(proc, options, step_args, step_builder)
        step_builder.(proc, *step_args.args_for_Step)
      end

      def build_task_for_macro(proc, options, step_args, step_builder)
        proc
      end

      module DeprecatedMacro # TODO: REMOVE IN 2.2.
        def build_task_for_macro(proc, *)
          if proc.is_a?(Proc)
            return proc if proc.arity != 2
          else
            return proc if proc.method(:call).arity != 2
          end

          warn %{[Trailblazer] Macros with API (input, options) are deprecated. Please use the "Task API" signature (direction, options, flow_options). (#{proc})}

          ->(direction, options, flow_options) do
            result    = proc.(flow_options[:exec_context], options) # run the macro, with the deprecated signature.
            direction = Step.binary_direction_for(result, Circuit::Right, Circuit::Left)

            [ direction, options, flow_options ]
          end
        end
      end
    end # DSL
  end
end