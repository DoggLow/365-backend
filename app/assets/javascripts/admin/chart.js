am4core.ready(function() {
    var data = [ {
        "pld": "CC PLD",
        "amount": 1
    }, {
        "pld": "My PLD",
        "amount": 1
    }, {
        "pld": "Address PLD",
        "amount": 1
    }];

    chartShow('chart_div');
    chartShow('chart_div_pool_1');
    chartShow('chart_div_pool_2');
    chartShow('chart_div_pool_3');
    chartShow('chart_div_pool_4');

    function chartShow(id) {
        chartEl = document.getElementById(id);
        chartData = chartEl.getAttribute("data-tree");
        flatData = JSON.parse(chartData);
        if (flatData.wallet_balance !== 0 || flatData.cc_balance !== 0){
            data[0].amount = flatData.wallet_balance
            data[1].amount = flatData.cc_balance
            data[2].amount = flatData.other_balance
        }

        var container = am4core.create(id, am4core.Container);
        container.width = am4core.percent(100);
        container.height = am4core.percent(100);
        container.layout = false;

        var colorSet = new am4core.ColorSet();
        colorSet.list = ["#fc0011", "#fc7e00", "#0288d1"].map(function(color) {
            return new am4core.color(color);
        });

        var chart = container.createChild(am4charts.PieChart);
        chart .fontSize = 8.5;
        chart.hiddenState.properties.opacity = 0;
        chart.data = data;
        chart.radius = am4core.percent(70);
        chart.innerRadius = am4core.percent(40);
        chart.zIndex = 1;

        var serise = chart.series.push(new am4charts.PieSeries());
        serise.dataFields.value = "amount";
        serise.dataFields.category = "pld";
        serise.colors = colorSet;
        serise.alignLabels = false;
        serise.labels.template.bent = false;

        serise.legend = new am4charts.Legend();
        serise.labels.template.padding(4,0,8);

        serise.ticks.template.disabled = false;
    }
});
