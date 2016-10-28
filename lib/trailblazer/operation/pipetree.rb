require "pipetree"

class Trailblazer::Operation
  New  = ->(klass, options) { klass.new(options) } # returns operation instance.
  Call = ->(operation, options) { operation.call(options["params"]) }          # returns #call result. # DISCUSS: do i like that?

  module Pipetree
    def self.included(includer)
      includer.extend ClassMethods
      includer.extend Pipe

      includer.| New
      includer.| Call
    end

    module ClassMethods
      # Top-level, this method is called when you do Create.() and where
      # all the fun starts.
      def call(options)
        pipe = self["pipetree"] # TODO: injectable? WTF? how cool is that?

        outcome = pipe.(self, options)

        outcome == ::Pipetree::Stop ? options : outcome # THIS SUCKS a bit.
      end
    end

    module Pipe
      def |(func, options=nil)
        heritage.record(:|, func, options)

        self["pipetree"] ||= ::Pipetree[]
        options ||= { append: true } # per default, append.

        self["pipetree"].insert!(func, options)#.class.inspect
      end
    end
  end
end

# TODO: test in pipetree_test the outcome of returning Stop. it's only implicitly tested with Policy.
