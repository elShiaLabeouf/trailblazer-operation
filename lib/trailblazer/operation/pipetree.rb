require "pipetree"

class Trailblazer::Operation
  New  = ->(klass, options) { klass.new(options[:skills]) } # returns operation instance.
  Call = ->(operation, options) { operation.call(options[:skills][:params]) }          # returns #call result. # DISCUSS: do i like that?

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
      def call(params={}, options={}, *dependencies)
        pipe = self["pipetree"] # TODO: injectable? WTF? how cool is that?

        result = {}
        # skills = Trailblazer::Skill.new(result, options, self.skills) # FIXME: redundant from Op::Skill.
        # DISCUSS: compute Skill right here?
        outcome = pipe.(self, { skills: options.merge(params: params), dependencies: dependencies })

        outcome == ::Pipetree::Stop ? result : outcome # THIS SUCKS a bit.
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