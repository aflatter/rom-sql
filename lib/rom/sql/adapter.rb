require 'logger'

require 'rom/sql/commands'

module ROM
  module SQL
    class Adapter < ROM::Adapter
      attr_reader :logger

      def self.schemes
        [:ado, :amalgalite, :cubrid, :db2, :dbi, :do, :fdbsql, :firebird,
         :ibmdb, :informix, :jdbc, :mysql, :mysql2, :odbc, :openbase, :oracle,
         :postgres, :postgresql, :sqlanywhere, :sqlite, :sqlite3, :swift, :tinytds]
      end

      def self.normalize_scheme(input)
        scheme = input.dup
        scheme = 'sqlite' if scheme == 'sqlite3'
        scheme = 'postgres' if scheme == 'postgresql'

        if RUBY_ENGINE == 'jruby' && scheme != 'postgres'
          scheme.prepend('jdbc:')
        end

        scheme
      end

      def self.database_file?(scheme)
        scheme.to_s.include?('sqlite')
      end

      def setup
        @connection = ::Sequel.connect(uri.to_s, options)
      end

      def disconnect
        connection.disconnect
      end

      def [](name)
        connection[name]
      end

      def logger=(logger)
        @logger = logger
        connection.loggers << logger
      end

      def schema
        tables
      end

      def dataset(table)
        connection[table]
      end

      def dataset?(name)
        tables.include?(name)
      end

      def extend_relation_class(klass)
        klass.send(:include, RelationInclusion)
      end

      def extend_relation_instance(relation)
        model = relation.model
        model.set_dataset(relation.dataset)
        model.dataset.naked!
      end

      def command_namespace
        SQL::Commands
      end

      private

      def tables
        connection.tables
      end

      def columns(table)
        dataset(table).columns
      end

      def attributes(table)
        map_attribute_types connection.schema(table)
      end

      def map_attribute_types(attrs)
        attrs.map do |column, opts|
          [column, { type: map_schema_type(opts[:type]) }]
        end.to_h
      end

      def map_schema_type(type)
        connection.class::SCHEMA_TYPE_CLASSES.fetch(type)
      end
    end
  end
end
