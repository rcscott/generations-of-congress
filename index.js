var app = new Vue({
  el: '#app',

  data: {
    generations: [
      // Ignoring generations anyone born before 1883, and Generation Z or later (no reps yet)
      'Lost Generation',
      'Greatest Generation',
      'Silent Generation',
      'Baby Boomers',
      'Generation X',
      'Millennials',
    ],
  },

  mounted: function () {
    $.ajax({
      url: 'senate_generation_percentages_per_day.json',
      success: function (data) {
        this.generateChart(JSON.parse(data), '#senate-chart', 'Senators');
      },
    });

    $.ajax({
      url: 'representative_generation_percentages_per_day.json',
      success: function (data) {
        this.generateChart(JSON.parse(data), '#representatives-chart', 'Representatives');
      },
    });
  },

  methods: {
    generateChart: function (generationPercentagesPerDay, chartId, humanReadableGroup) {
      let chartDatasets = _.map(this.generations, (generation) => {
        data = _.map(generationPercentagesPerDay[generation], (generation_count, day) => {
          return { x: day, y: generation_count };
        });
        data = _.compact(data);
        data = _.sortBy(data, ['x']);

        return {
          label: generation,
          data: data,
          pointRadius: 0,
        };
      });

      this.chart = new Chart($(chartId), {
        type: 'line',
        data: {
          datasets: chartDatasets,
        },
        options: {
          responsive: true,
          title: {
            display: true,
            text: `Generations of ${humanReadableGroup}`,
          },
          tooltips: {
            mode: 'index',
            callbacks: {
              label: function(tooltipItem, data) {
                return `${data.datasets[tooltipItem.datasetIndex].label}: ${tooltipItem.yLabel}%`;
              },
            },
          },
          hover: {
            mode: 'index',
          },
          scales: {
            xAxes: [{
              type: 'time',
              display: true,
              scaleLabel: {
                display: true,
                labelString: 'Date',
              },
            }],
            yAxes: [{
              display: true,
              scaleLabel: {
                display: true,
                labelString: `Percentage of ${humanReadableGroup}`,
              },
              ticks: {
                callback: function (value) {
                  return `${value}%`;
                },
              },
            }],
          },
          plugins: {
            colorschemes: {
              scheme: 'brewer.SetTwo6',
              fillAlpha: 0.1,
            },
          },
        },
      });
    },
  },
});
