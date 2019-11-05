am4core.ready(function() {
    var total_data = [ {
        "pld": "Mine",
        "amount": 1
    }, {
        "pld": "Total",
        "amount": 1
    }];

    var pool_data = [
        [{
            "pld": "Mine",
            "amount": 0
        }, {
            "pld": "Total",
            "amount": 1
        }],
        [{
            "pld": "Mine",
            "amount": 0
        }, {
            "pld": "Total",
            "amount": 1
        }],
        [{
            "pld": "Mine",
            "amount": 0
        }, {
            "pld": "Total",
            "amount": 1
        }],
        [{
            "pld": "Mine",
            "amount": 0
        }, {
            "pld": "Total",
            "amount": 1
        }],
    ];
    
    chartShow('chart_div');
    poolChartShow('chart_div_pool_1', 1);
    poolChartShow('chart_div_pool_2', 2);
    poolChartShow('chart_div_pool_3', 3);
    poolChartShow('chart_div_pool_4', 4);

    function chartShow(id) {
        chartEl = document.getElementById(id);
        chartData = chartEl.getAttribute("data-tree");
        flatData = JSON.parse(chartData);
        if (flatData.other_balance !== 0 || flatData.cc_balance !== 0){
            total_data[0].amount = Number(flatData.cc_balance) + Number(flatData.other_balance)
            total_data[1].amount = Number(flatData.total) - total_data[0].amount
        }

        var container = am4core.create(id, am4core.Container);
        container.width = am4core.percent(100);
        container.height = am4core.percent(100);
        container.layout = false;

        var colorSet = new am4core.ColorSet();
        colorSet.list = ["#eb6100", "#025295"].map(function(color) {
            return new am4core.color(color);
        });

        var chart = container.createChild(am4charts.PieChart);
        chart .fontSize = 8.5;
        chart.hiddenState.properties.opacity = 0;
        chart.data = total_data;
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

    function poolChartShow(id, pool_id) {
        chartEl = document.getElementById(id);
        chartData = chartEl.getAttribute("data-tree");
        flatData = JSON.parse(chartData);
        let total = 0
        if (!!flatData.pools[pool_id - 1]) {
            let total = flatData.pools[pool_id - 1]['sum'];
            let share = Number(flatData.pools[pool_id - 1]['share']);
            let pool_balance = total * share;
            let other_pool_balance = total - pool_balance;
            if (total > 0) {
                pool_data[pool_id - 1][0].amount = pool_balance;
                pool_data[pool_id - 1][1].amount = other_pool_balance;
            }
        } else {
            pool_data[pool_id - 1][0].amount = 0;
            pool_data[pool_id - 1][1].amount = 0.0000001;
        }


        var container = am4core.create(id, am4core.Container);
        container.width = am4core.percent(100);
        container.height = am4core.percent(100);
        container.layout = false;

        var colorSet = new am4core.ColorSet();
        colorSet.list = ["#eb6100", "#025295"].map(function(color) {
            return new am4core.color(color);
        });

        var chart = container.createChild(am4charts.PieChart);
        chart .fontSize = 8.5;
        chart.hiddenState.properties.opacity = 0;
        chart.data = pool_data[pool_id - 1];
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
