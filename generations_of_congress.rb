require 'date'
require 'httparty'
require 'json'
require 'rails'
require 'byebug'

def get_active_legislators_by_day
  puts 'Downloading current legislator data'
  legislators = JSON.parse(HTTParty.get('https://theunitedstates.io/congress-legislators/legislators-current.json').body)

  puts 'Downloading historical legislator data'
  legislators += JSON.parse(HTTParty.get('https://theunitedstates.io/congress-legislators/legislators-historical.json').body)

  active_senators_by_day = Hash.new { |h, k| h[k] = [] }
  active_representatives_by_day = Hash.new { |h, k| h[k] = [] }

  legislators.each do |legislator|
    legislator['terms'].each do |term|
      (Date.parse(term['start'])..Date.parse(term['end'])).each do |day|
        if term['type'] == 'sen'
          active_senators_by_day[day] << legislator
        elsif term['type'] == 'rep'
          active_representatives_by_day[day] << legislator
        end
      end
    end
  end

  {
    active_senators_by_day: active_senators_by_day,
    active_representatives_by_day: active_representatives_by_day,
  }
end

def get_generations_by_year
  generations = JSON.parse(File.read('generations.json'))

  generations.map do |gen|
    (gen['startYear']..gen['endYear']).map do |year|
      [year, gen['name']]
    end
  end.flatten(1).to_h
end

def counts_to_percentages(generation_counts)
  # Calculate the rounded percentage of each generation, and ensure that the total adds up to 100%
  # Taken from https://revs.runtime-revolution.com/getting-100-with-rounded-percentages-273ffa70252b
  total_count = generation_counts.values.map(&:floor).reduce(&:+).to_f
  generation_percentages = generation_counts.map do |generation, count|
    percentage = count / total_count * 100
    [generation, percentage]
  end.to_h

  diff = 100 - generation_percentages.values.map(&:floor).reduce(&:+)

  generation_percentages = generation_percentages.sort_by { |generation, percentage| percentage.floor - percentage }
  generation_percentages.map.with_index do |generation_percentage, index|
    rounded_percentage = index < diff ? generation_percentage[1].floor + 1 : generation_percentage[1].floor
    [generation_percentage[0], rounded_percentage]
  end.to_h
end

def generations_of_congress_per_day(generations_by_year, legislators_by_day)
  start_date = Date.new(1910, 1, 1)
  end_date = Date.new(2018, 12, 31)
  previous_day_counts = Hash.new

  # Return data structure: {"Generation Name": {"1900-01-01": 5}}
  generation_percentages_per_day = Hash.new { |h, k| h[k] = Hash.new }

  (start_date..end_date).each do |day|
    current_day_counts = generations_by_year.values.map { |generation| [generation, 0] }.to_h

    legislators_by_day[day].each do |legislator|
      if birthday = legislator.dig('bio', 'birthday')
        generation = generations_by_year[Date.parse(birthday).year]
        current_day_counts[generation] += 1
      else
        # generation = 'Unknown'
      end
    end

    # Ignore day if there is only 1 member total, or if all values are 0
    next if current_day_counts.values.sum <= 1

    # Ignore day if unchanged from previous unique day
    next if current_day_counts == previous_day_counts

    previous_day_counts = current_day_counts
    current_day_percentages = counts_to_percentages(current_day_counts)
    puts "#{day}:\n\tCounts: #{current_day_counts}\n\tPercentages: #{current_day_percentages}"

    current_day_percentages.each do |generation, percentage|
      generation_percentages_per_day[generation][day] = percentage
    end
  end

  generation_percentages_per_day
end


generations_by_year = get_generations_by_year
active_legislators_by_day = get_active_legislators_by_day

puts "*** Generating Senate data ***"
senate_percentages_per_day = generations_of_congress_per_day(
  generations_by_year, active_legislators_by_day[:active_senators_by_day])
File.write("senate_generation_percentages_per_day.json", JSON.generate(senate_percentages_per_day))

puts "*** Generating House of Representatives data ***"
representative_percentages_per_day = generations_of_congress_per_day(
  generations_by_year, active_legislators_by_day[:active_representatives_by_day])
File.write("representative_generation_percentages_per_day.json", JSON.generate(representative_percentages_per_day))
