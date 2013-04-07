module Skylight
  class Trace
    KEY = :__skylight_current_trace

    def self.current
      Thread.current[KEY]
    end

    # Struct to track each span
    class Span < Struct.new(
      :parent,
      :started_at,
      :category,
      :title,
      :description,
      :annotations,
      :ended_at)

      def key
        @key ||= [category, description]
      end
    end

    attr_reader :endpoint, :ident, :spans
    attr_writer :endpoint

    def initialize(endpoint = "Unknown", ident = nil)
      @ident    = ident
      @endpoint = endpoint
      @spans    = []

      # Tracks the ID of the current parent
      @parent = nil
    end

    def from
      return unless span = @spans.first
      span.started_at
    end

    def to
      return unless span = @spans.last
      span.ended_at
    end

    def record(cat, title, desc, annot)
      span = build_span(cat, title, desc, annot)
      span.ended_at = span.started_at

      @spans << span

      self
    end

    def start(cat, title, desc, annot)
      span = build_span(cat, title, desc, annot)

      @parent = @spans.length

      @spans << span

      self
    end

    def stop
      # Find last unclosed span
      span = @spans.last
      while span && span.ended_at
        span = span.parent ? @spans[span.parent] : nil
      end

      raise "trace unbalanced" unless span

      # Set ended_at
      span.ended_at = now

      # Update the parent
      @parent = @spans[@parent].parent

      self
    end

    # Requires global synchronization
    def commit
      raise "trace unbalanced" if @parent

      @ident ||= gen_ident

      # No more changes should be made
      freeze

      self
    end

  private

    def now
      Util.clock.now
    end

    def gen_ident
      Util::UUID.gen Digest::MD5.digest(@endpoint)[0, 2]
    end

    def build_span(cat, title, desc, annot)
      Span.new(@parent, now, cat, title, desc, annot)
    end

  end
end
