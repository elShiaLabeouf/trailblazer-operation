module Trailblazer
  module Operation::Railway
    # Implements the fail_fast/pass_fast logic by connecting each task to the two
    # special end events.
    module FastTrack
      # modules for declarative APIs are fine.
      def self.included(includer)
        # add additional end events to the circuit.
        includer.extend(DSL)

        # includer["__wirings__"] += DSL.initial_fast_tracks
      end

      module DSL
        def InitialActivity # FIXME: make this cooler!
          super.tap do |start|
            end_for_pass_fast = Class.new(End::Success).new(:pass_fast)
            end_for_fail_fast = Class.new(End::Failure).new(:fail_fast)

            start.attach!( target: [ end_for_pass_fast, id: "End.pass_fast" ], edge: [ PassFast, type: :railway ] )
            start.attach!( target: [ end_for_fail_fast, id: "End.fail_fast" ], edge: [ FailFast, type: :railway ] )
          end
        end

        # TODO: how to make this better overridable without super?
        def initial_activity
          end_for_pass_fast = Class.new(End::Success).new(:pass_fast)
          end_for_fail_fast = Class.new(End::Failure).new(:fail_fast)


          super + [
            [ :attach!, target: [ end_for_pass_fast, id: "End.pass_fast" ], edge: [ PassFast, type: :railway ] ],
            [ :attach!, target: [ end_for_fail_fast, id: "End.fail_fast" ], edge: [ FailFast, type: :railway ] ],
          ]
        end

        def task_outputs_for_step(options)
          return super.merge( FailFast => { role: :fail_fast }, PassFast => { role: :pass_fast } ) if options[:fast_track]
          super
        end

        def task_outputs_for_pass(options)
          return super.merge( FailFast => { role: :fail_fast }, PassFast => { role: :pass_fast } ) if options[:fast_track]
          super
        end

        def task_outputs_for_pass(options)
          return super.merge( FailFast => { role: :fail_fast }, PassFast => { role: :pass_fast } ) if options[:fast_track]
          super
        end

        # Called in DSL::pass
        def output_mappings_for_pass(task, options)
          target = "End.pass_fast"

          return super.merge(success: target, failure: target) if options[:pass_fast]
          super

          # {
          #   :success => "End.success",
          #   :failure => "End.success"
          # }
        end

        # Called in DSL::fail
        def output_mappings_for_fail(task, options)
          target = "End.fail_fast"

          step_options = {}
          step_options = step_options.merge( fail_fast: target ) # always add edge to fail_fast?

          step_options = step_options.merge( failure: target, success: target ) if options[:fail_fast]

          super.merge(step_options)
        end

        # Called in DSL::step
        def output_mappings_for_step(task, options)
          step_options = {
            success: output_mappings_for_pass(task, options)[:success],
            failure: output_mappings_for_fail(task, options)[:failure],
            pass_fast: "End.pass_fast",
            fail_fast: "End.fail_fast", # always add edge to fail_fast?
          }

          super.merge(step_options)
        end

      end
    end

    module_function

    def fail!     ; Circuit::Left  end
    def fail_fast!; FailFast       end
    def pass!     ; Circuit::Right end
    def pass_fast!; PassFast       end

    private

    # Direction signals.
    class FailFast < Circuit::Left;  end
    class PassFast < Circuit::Right; end
  end
end
