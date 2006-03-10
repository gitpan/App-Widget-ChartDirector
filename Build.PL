
use App::Build;

my $build = App::Build->new (
    dist_name         => "App-Widget-ChartDirector",
    dist_version      => "0.50",
    dist_author       => "stephen.adkins\@officevision.com",
    dist_abstract     => "A graphing widget which displays graphs and charts for web applications using the ChartDirector graphing library within the App-Context/App-Widget widget framework",
    license           => "perl",
    requires => {
        "App::Options"   => 0,  # needed for option parsing
    },
    build_requires => {
        "App::Build"     => 0,  # needed for installing the software
        "Module::Build"  => 0,  # needed for installing the software
        "File::Spec"     => 0,  # platform-neutral directory processing
    },
    extra_dirs => [ "cgi-bin", ],
    dynamic_config => 1,
);

$build->create_build_script;

