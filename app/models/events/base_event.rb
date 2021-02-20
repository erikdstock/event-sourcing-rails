##
# An abstract base event that dynamically defines our associated aggregates and payload attributes
# Kickstarter code reference:
# https://github.com/pcreux/event-sourcing-rails-todo-app-demo/blob/master/app/models/lib/base_event.rb
# Source: https://dev.to/isalevine/building-an-event-sourcing-pattern-in-rails-from-scratch-355h
class Events::BaseEvent < ActiveRecord::Base
  before_validation :find_or_build_aggregate
  before_create :apply_and_persist
  self.abstract_class = true

  def apply(aggregate)
    raise NotImplementedError
  end

  after_initialize do
    self.event_type = event_type
    self.payload ||= {}
  end

  ##
  # Define getters and setters for event payloads
  # @usage: payload_attributes :name, :email, :password
  def self.payload_attributes(*attributes)
    @payload_attributes ||= []

    attributes.map(&:to_s).each do |attribute|
      @payload_attributes << attribute unless @payload_attributes.include?(attribute)

      define_method attribute do
        self.payload ||= {}
        self.payload[attribute]
      end

      define_method "#{attribute}=" do |argument|
        self.payload ||= {}
        self.payload[attribute] = argument
      end
    end

    @payload_attributes
  end

  ##
  # Get name of aggregate from belongs_to association
  def self.aggregate_name
    inferred_aggregate = reflect_on_all_associations(:belongs_to).first
    raise 'Events must belong to an aggregate' if inferred_aggregate.nil?

    inferred_aggregate.name
  end

  ##
  # Methods for dynamically handling aggregates
  #
  # To round out our events’ functionality, we’ll want some setters and getters—as well as methods to easily return its type or class name:
  # aggregate=(model) and aggregate will set and get the User our event targets
  # aggregate_id=(id) and aggregate_id will map to the user_id field on our user_events table
  # self.aggregate_name gives the Event class awareness of its belongs_to relationship’s target class (#=> User)
  # delegate :aggregate_name, to: :class will return a Symbol of the aggregate’s class name (#=> :user)
  # event_klass will convert our Event class’s ::BaseEvent namespace into its appropriate event type (#=> Events::User::Created)
  delegate :aggregate_name, to: :class

  def aggregate
    public_send aggregate_name
  end

  def aggregate=(model)
    public_send "#{aggregate_name}=", model
  end

  def aggregate_id
    public_send "#{aggregate_name}_id"
  end

  def aggregate_id=(id)
    public_send "#{aggregate_name}_id=", id
  end

  def event_type
    attributes['event_type'] || self.class.to_s.split('::').last
  end

  def event_klass
    klass = self.class.to_s.split('::')
    klass[-1] = event_type
    klass.join('::').constantize
  end

  private

  def apply_and_persist
    # Lock the database row! (OK because we're in an ActiveRecord callback chain transaction)
    aggregate.lock! if aggregate.persisted?

    # Apply!
    self.aggregate = apply(aggregate)

    # Persist!
    aggregate.save!

    # Update aggregate_id with id from newly created User
    self.aggregate_id = aggregate.id if aggregate_id.nil?
  end

  def find_or_build_aggregate
    self.aggregate = find_aggregate if aggregate_id.present?
    self.aggregate = build_aggregate if aggregate.nil?
  end

  def find_aggregate
    klass = aggregate_name.to_s.classify.constantize
    klass.find(aggregate_id)
  end

  def build_aggregate
    public_send "build_#{aggregate_name}"
  end
end
