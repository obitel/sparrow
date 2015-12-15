package Sparrow::Commands::Plugin;

use strict;

use base 'Exporter';

use Sparrow::Constants;
use Sparrow::Misc;

use Carp;
use File::Basename;
use HTTP::Tiny;
use JSON;
use version;


use constant sparrow_hub_api_url => 'http://127.0.0.1:3000';

our @EXPORT = qw{

    search_plugins

    show_installed_plugins    

    install_plugin

    show_plugin

    remove_plugin

    upload_plugin

};


sub search_plugins {

    my $pattern  = shift or confess 'usage: search_plugins(pattern)';

    my $list = read_plugin_list();

    print "[found sparrow plugins]\n\n";
    print "type    name\n\n";
    

    my $re = qr/$pattern/; 
    for my $p (grep { $_->{name}=~ $re }   @{$list}){
        print "$p->{type}\t$p->{name}\n";
    }
}


sub show_installed_plugins {

    print "[installed sparrow plugins]\n\n";

    print "[public]\n\n";

    my $root_dir = sparrow_root.'/plugins/public';

    opendir(my $dh, $root_dir) || confess "can't opendir $root_dir: $!";

    for my $p (grep { ! /^\.{1,2}$/ } readdir($dh)){
        print basename($p),"\n";
    }

    closedir $dh;

    print "\n\n[private]\n\n";

    my $root_dir = sparrow_root.'/plugins/private';

    opendir(my $dh, $root_dir) || confess "can't opendir $root_dir: $!";

    for my $p (grep { ! /^\.{1,2}$/ } readdir($dh)){
        print basename($p),"\n";
    }

    closedir $dh;

}


sub install_plugin {

    my $pid     = shift or confess 'usage: install_plugin(name,type)';
    my $type    = shift;

    my $list = read_plugin_list('as_hash');

    if ($list->{'public@'.$pid} && $list->{'private@'.$pid} && ! $type){
        warn "both public and private $pid plugin found, use --private or --public flag to choose which you want to install";
        return;
    }elsif ($type) {

        confess 'type should be one of two: private|public' unless $type=~/--(private|local)$/;
        print "installing $type\@$pid ...\n";

    }elsif($list->{'public@'.$pid}) {

    if ( -f sparrow_root."/plugins/public/$pid/sparrow.json" ){

            open F, sparrow_root."/plugins/public/$pid/sparrow.json" or confess "can't open file to read: $!";
            my $sp = join "", <F>;
            my $spj = decode_json($sp);
            close F;

            my $plg_v  = version->parse($list->{'public@'.$pid}->{version});
            my $inst_v = version->parse($spj->{version});

            if ($plg_v > $inst_v){

                print "upgrading public\@$pid from version $inst_v to version $plg_v ...\n";

                execute_shell_command("rm -rf ".sparrow_root."/plugins/public/$pid");

                execute_shell_command("mkdir ".sparrow_root."/plugins/public/$pid");

                execute_shell_command("cd ".sparrow_root."/plugins/public/$pid && \\ 
                curl -s -w 'Download %{url_effective} --- %{http_code}' -f -o  \\
                $pid-v$plg_v.tar.gz ".sparrow_hub_api_url."/plugins/$pid-v$plg_v.tar.gz");

                execute_shell_command("echo; cd ".sparrow_root."/plugins/public/$pid && tar -xzf $pid-v$plg_v.tar.gz && carton");

            }else{
                print "public\@$pid is uptodate ($inst_v)\n";
            }

        }else{

            my $v = $list->{'public@'.$pid}->{version};

            print "installing public\@$pid version $v ...\n";

            execute_shell_command("rm -rf ".sparrow_root."/plugins/public/$pid");

            execute_shell_command("mkdir ".sparrow_root."/plugins/public/$pid");

            execute_shell_command("cd ".sparrow_root."/plugins/public/$pid &&  \\
            curl -s -w 'Download %{url_effective} --- %{http_code}' -f -o \\
            $pid-v$v.tar.gz ".sparrow_hub_api_url."/plugins/$pid-v$v.tar.gz");

            execute_shell_command("echo; cd ".sparrow_root."/plugins/public/$pid && tar -xzf $pid-v$v.tar.gz && carton");

        }
        
    }elsif($list->{'private@'.$pid}) {
        print "installing private\@$pid ...\n";
        if ( -d sparrow_root."/plugins/private/$pid" ){
            execute_shell_command("cd ".sparrow_root."/plugins/private/$pid && git pull");
            execute_shell_command("cd ".sparrow_root."/plugins/private/$pid && carton");
        }else{
            execute_shell_command("git clone  ".($list->{'private@'.$pid}->{url}).' '.sparrow_root."/plugins/private/$pid");
            execute_shell_command("cd ".sparrow_root."/plugins/private/$pid && carton");
        }

    }else{
        confess "unknown plugin type: $list->{type}";
    }


}
sub show_plugin {

    my $pid = shift or confess 'usage: show_plugin(plugin_name)';

    my $list = read_plugin_list('as_hash');

    my $installed = ( -f sparrow_root."/plugins/public/$pid/sparrow.json" or -d sparrow_root."/plugins/private/$pid/" ) ? 1 : 0;

    my $listed = ( $list->{'public@'.$pid} or $list->{'private@'.$pid} ) ? 1 : 0;

    if ($listed and $list->{'public@'.$pid} ) {

        my $inst_version = '';
        my $desc = '';

        if ( open F, sparrow_root."/plugins/public/$pid/sparrow.json" ){
            my $s = join "", <F>;
            close F;
            my $spj = decode_json($s);
            $inst_version = eval { version->parse($spj->{version})->numify };
            $desc = $spj->{desciption};
        } else {
            $inst_version = 'unknown';
            $desc = 'unknown';
        }


        print "plugin name: $pid\n";
        print "plugin type: public\n";
        print "installed: ",($installed ? 'YES':'NO'),"\n";
        print "plugin version: ",$list->{'public@'.$pid}->{version},"\n";
        print "plugin installed version: ",$inst_version,"\n" if $installed;
        print "plugin desciption: $desc\n";

    }

    if( $listed and $list->{'private@'.$pid} ) {
        print "plugin name: $pid\n";
        print "plugin type: private\n";
        print "installed: ",($installed ? 'YES':'NO'),"\n";
    }

    if (! $listed ) {
        if ( -f sparrow_root."/plugins/public/$pid/sparrow.json" ){
            print "public\@$pid plugin installed, but not found at sparrow index. is it obsolete plugin?\n";
        }
        if ( -d sparrow_root."/plugins/private/$pid" ){
            print "private\@$pid plugin installed, but not found at sparrow index. is it obsolete plugin?\n";
        }
        warn "unknown plugin" unless $installed;
    }

}

sub remove_plugin {

    my $pid = shift or confess('usage: remove_plugin(*plugin_name)');
    my $rm_cnt = 0;

    if (-d sparrow_root."/plugins/public/$pid"){
        print "removing public\@$pid ...\n";
        execute_shell_command("rm -rf ".sparrow_root."/plugins/public/$pid/");
        $rm_cnt++;
    }

    if (-d sparrow_root."/plugins/private/$pid"){
        print "removing private\@$pid ...\n";
        execute_shell_command("rm -rf ".sparrow_root."/plugins/private/$pid/");
        $rm_cnt++;
    }

    warn "plugin is not installed" unless $rm_cnt;

}

sub read_plugin_list {

    my @list;
    my %list;

    my $mode = shift || 'as_array';


    my $index_url = sparrow_hub_api_url.'/api/v1/index';

    my $response = HTTP::Tiny->new->get($index_url);
 
    if ($response->{success}){
        for my $i (split "\n", $response->{content}){
            next unless $i=~/\S+/;
            my @foo = split /\s+/, $i;
            push @list, { name => $foo[0], version => $foo[1], type => 'public' } ;
            $list{'public@'.$foo[0]} = { name => $foo[0], version => $foo[1], type => 'public'  };
        } 
    }else{
        confess "bad response from $index_url\n$response->{status}\n$response->{reason}\n";
    }

    open F, spl_file or confess $!;

    while ( my $i = <F> ){
        chomp $i;
        next unless $i=~/\S+/;
        my @foo = split /\s+/, $i;
        push @list, { name => $foo[0], url => $foo[1], type => 'private' } ;
        $list{'private@'.$foo[0]} = { name => $foo[0], url => $foo[1], type => 'private' };
    }

    close F;

    my $retval;

    if ($mode eq 'as_hash'){
        $retval = \%list;
    }else{
        $retval = \@list;
    }

    return $retval;

}

sub upload_plugin {

    open F, "$ENV{HOME}/sparrowhub.json" or confess "can't open $ENV{HOME}/sparrowhub.json to read: $!";
    my $s = join "", <F>;
    close F;

    my $cred = decode_json($s);

    open F, 'sparrow.json' or confess "can't open sparrow.json to read: $!";
    $s = join "", <F>;
    close F;

    my $spj = decode_json($s);

    # validating json file

    my $plg_v    = version->parse($spj->{version}) or confess "version not found in sparrow.json file";;
    my $plg_name = $spj->{name} or confess "name not found in sparrow.json file";

    $plg_name=~/^[\w\d-\._]+$/ or confess 'name parameter does not meet naming requirements - /^[\w\d-\._]+$/';

    print "sparrow.json file validated ... \n";

    execute_shell_command('tar --exclude=local --exclude=*.log  --exclude=log  --exclude-vcs -zcf /tmp/archive.tar.gz .' );
    execute_shell_command(
        "curl -H 'sparrow-user: $cred->{user}' " .
        "-H 'sparrow-token: $cred->{token}' " .
        '-f -X POST '.sparrow_hub_api_url.'/api/v1/upload -F archive=@/tmp/archive.tar.gz');

}


1;

