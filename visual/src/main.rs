use sscanf::scanf;

struct ChartSource {
    path: std::ops::Range<String>,
    view: plotlib::view::CategoricalView,
}

fn main() {
    let output = std::process::Command::new("build/bench")
        .current_dir(std::env::current_dir().unwrap().parent().unwrap())
        .output()
        .expect("Failed to execute the bench");
    let out_str = std::str::from_utf8(&output.stdout).unwrap();

    let mut sources = Vec::<ChartSource>::new();
    for line in out_str.lines() {
        if let Ok((name, value)) = scanf!(line, "\t{}: {} us", String, f64) {
            let color = match name.as_str() {
                "naga" => "blue",
                "tint" => "green",
                "cross" => "red",
                "glslang" => "gray",
                _ => "black",
            };
            let bar = plotlib::repr::BarChart::new(value / 1000.0)
                .style(&plotlib::style::BoxStyle::new().fill(color))
                .label(name);

            let ChartSource { path, view } = sources.pop().unwrap();
            sources.push(ChartSource {
                path,
                view: view.add(bar),
            });
        } else if let Ok((from, to, _)) = scanf!(line, "{} -> {} ({})", String, String, str) {
            let name = format!("{} -> {} time (ms)", from, to);
            sources.push(ChartSource {
                path: from..to,
                view: plotlib::view::CategoricalView::new().y_label(&name),
            });
        } else {
            println!("Unrecognized line: {}", line);
        }
    }

    for source in sources.iter() {
        let chart_name = format!("products/{}2{}.svg", source.path.start, source.path.end);
        println!("Saving {}", chart_name);
        plotlib::page::Page::single(&source.view)
            .dimensions(400, 400)
            .save(&chart_name)
            .expect("saving png");
    }
}
