module HasManyPolymorphs
  module ActiveRecordFix
    extend ActiveSupport::Concern

    module ClassMethods
      def collection_reader_method(reflection, association_proxy_class)
        redefine_method(reflection.name) do |*params|
          force_reload = params.first unless params.empty?
          association = association_instance_get(reflection.name)

          unless association
            association = association_proxy_class.new(self, reflection)
            association_instance_set(reflection.name, association)
          end

          reflection.klass.uncached { association.reload } if force_reload

          association
        end

        redefine_method("#{reflection.name.to_s.singularize}_ids") do
          if send(reflection.name).loaded? || reflection.options[:finder_sql]
            send(reflection.name).map { |r| r.id }
          else
            if reflection.through_reflection && reflection.source_reflection.belongs_to?
              through = reflection.through_reflection
              primary_key = reflection.source_reflection.primary_key_name
              send(through.name).select("DISTINCT #{through.quoted_table_name}.#{primary_key}").map! { |r| r.send(primary_key) }
            else
              send(reflection.name).select("#{reflection.quoted_table_name}.#{reflection.klass.primary_key}").except(:includes).map! { |r| r.id }
            end
          end
        end
      end
    end
  end
end
