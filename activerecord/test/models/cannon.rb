# frozen_string_literal: true

class Cannon < ActiveRecord::Base
  belongs_to :ship
  belongs_to :pirate
end
