package Koha::Plugin::Com::BM::Plocklista;

use strict;

use base qw(Koha::Plugins::Base);
#use Koha::Database;

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::HoldsQueue qw( GetHoldsQueueItems );
use Koha::BiblioFrameworks;
use Koha::ItemTypes;

use utf8;

use warnings;

our $VERSION = "1.32";


our $metadata = {
    name            => 'Enkel plocklista',
    author          => 'Johan Sahlberg',
    date_authored   => '2023-08-08',
    date_updated    => "2025-08-27",
    minimum_version => 22.05,
    maximum_version => '',
    version         => $VERSION,
    description     => 'Förenklad plocklista för användning på mobila enheter'
};

#my $debug = 1;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{'class'} = $class;

    return $self;
}

sub intranet_js {
    
    return <<'EOF';
<script>
    (function () {
        var load = function load () {
            if (window.jQuery) {
                window.jQuery(document).ready(function () {
                    init(window.jQuery);
                });
            } else {
                setTimeout(load, 50);
            }
        };
        load();

        function controlDate(date, today) {
            var returndate = date.replace(/\D/g, '');
            var rYear = returndate.slice(0, 4);
            var rMonth = returndate.slice(4, 6);
            var rDay = returndate.slice(6, 8);
            returndate = new Date()
            returndate.setFullYear(rYear, rMonth - 1, rDay);
            var diffTime = Math.abs(today - returndate);
            var diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            if (diffDays < 2) {
                console.log('Mindre än 2 dagar');
                return true;
            } else {
                return false;
            }
        }

        var init = function init ($) {
            if ($('#circ_view_holdsqueue').length) { 
                const button = document.createElement("button");
                button.classList.add("btn", "btn-default");
                button.innerHTML = '<i class="fa fa-search"></i> Plocklista (Mobilvariant)';
                button.addEventListener("click", function (ev) {
                    ev.preventDefault();
                    var bibl = $('.logged-in-branch-code:first').text();
                    window.open("/cgi-bin/koha/plugins/run.pl?class=" + encodeURIComponent("Koha::Plugin::Com::BM::Plocklista") + "&method=getPlocklista&branchlimit=" + bibl + "&run_report=1");
                });
                const tlm = document.querySelector('.results');
                if (tlm) {
                    tlm.insertAdjacentElement('beforebegin', button);
                }
            }

            if ($('#plocklista').length) {
                var today = new Date();

                $('.hq-barcode strong').each(function() {
                    var barcode = $(this).text();
                    var thisbarcode = $(this).parent();
                    $.ajax({
                        url: 'https://' + window.location.hostname + '/api/v1/items/?external_id=' + barcode + '&_match=exact',
                        cache: true,
                        success: function(data) {
                            if(data[0] != null) {
                                var lastseen = data[0].last_seen_date;
                                lastseen = lastseen.slice(0, 10);
                                if (controlDate(lastseen, today)) {
                                    $('<div style="margin-top:10px;color:#900">Senast sedd: ' + lastseen + '</div>').appendTo(thisbarcode);
                                } else {
                                    $('<div style="margin-top:10px">Senast sedd: ' + lastseen + '</div>').appendTo(thisbarcode);
                                }
                                data[0].last_checkout_date ? null : $('<br /><span style="color:#900">Aldrig varit utlånad!</span>').appendTo(thisbarcode);
                            }
                        }
                    });
                });
            

                $('.hq-biblionumber').each(function() {
                    var bibnr = $(this).text();

                    var loc = $(this);
                    var url = '/api/v1/biblios/' + bibnr;
                    $.ajax({
                        type: "GET",
                        accepts: {
                        "*": "application/marc-in-json"
                        },
                        //contentType: "application/marc-in-json;charset=ISO-8859-15",
                        url: url,
                        complete: function(data) {
                            //console.log(data.responseJSON.fields);
                            data.responseJSON.fields.forEach(function(item) {
                                if (Object.keys(item)[0] == '490') {
                                    var the_subfields = item['490'].subfields;
                                    if (the_subfields.length > 1) {
                                        var seriesdata = the_subfields[0].a + ' ' + the_subfields[1].v;
                                        try {
                                            seriesdata = decodeURIComponent(escape(seriesdata));
                                            // expected output: "https://mozilla.org/?x=ÑˆÐµÐ»Ð»Ñ‹"
                                        } catch (e) { // catches a malformed URI
                                            //console.error(e);
                                            console.log(seriesdata)
                                        }
                                        $('<div class="hq-pubdata" style="color:#900">Serie: ' + seriesdata + '</div>').appendTo(loc.closest('td'));
                                    }
                                }
                            });
                        }
                    });
                });
                
                
                setTimeout(function() {
                    $('.coverIMG').each(function() {
                               
                        var isbn = $(this).attr('id');
                        if (isbn.includes('|')) {
                            isbn = isbn.slice(0, isbn.indexOf('|')).replace(/\D/g, '');
                        }
                        //console.log(isbn);
                        if (isbn.slice(0, 3) == '978') {
                            isbn = isbn.slice(0, 13);
                            var subfolder = isbn.slice(0, 6);
                        } else {
                            isbn = '978' + isbn.slice(0, -1);
                            var subfolder = isbn.slice(0, 6);
                            isbnNr = parseInt(isbn, 10);
                            var sum = 0;
                            for (var x = 0; x < isbn.length; x++) {
                            if (x === 0) {
                                sum = sum + parseInt(isbn[x], 10);
                            } else if (x % 2 === 0) {
                                sum = sum + parseInt(isbn[x], 10);
                            } else {
                                sum = sum + (parseInt(isbn[x], 10) * 3);
                            }
                            }
                            sum = 10 - (sum % 10);
                            if (sum == 10) {
                            sum = 0;
                            }
                            isbn = isbnNr.toString();
                            isbn = isbn.concat(sum.toString());
                        }
                        if (isbn.length > 2) {
                            $(this).attr('src', 'https://www.bokinfo.se/Images/Products/Small/' + subfolder + '/' + isbn + '.jpg').change();
                        }
                        $(".coverIMG").on("error", function() {
                            $(this).remove();
                        });
                    });

                    $('#holdst tr td').each(function() {
                        $('<button class="hidebutton" style="float:right;height:50px;width:85px;">Dölj</button>').appendTo(this);
                        $('.hidebutton').on('click', function() {
                            $(this).closest('tr').hide();
                        });
                    });
                    
                    $('<button id="returnButton" style="float:right;font-size:large">Stäng</button>').insertBefore('.results');
                    $('#returnButton').on('click', function() {
                        window.close();
                    });

                    $('<button id="refreshButton" style="float:right;font-size:large">Uppdatera</button>').insertBefore('.results');
                    $('#refreshButton').on('click', function() {
                        location.reload();
                    });
                    
                }), 1000;
            }
        }
    })();
</script>
EOF
}
    

sub getPlocklista {
    my ( $self, $args ) = @_;
    # my $cgi = $self->{'cgi'};

    my $query = CGI->new;
    my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
        {
            template_name   => $self->mbf_path("Plocklista.tt"),
            query           => $query,
            type            => "intranet",
            flagsrequired   => { circulate => "circulate_remaining_permissions" },
        }
    );

    my $params = $query->Vars;
    my $run_report     = $params->{'run_report'};
    my $branchlimit    = $params->{'branchlimit'};
    my $itemtypeslimit = $params->{'itemtypeslimit'};
    my $ccodeslimit = $params->{'ccodeslimit'};
    my $locationslimit = $params->{'locationslimit'};

    if ( $run_report ) {
        my $items = GetHoldsQueueItems({
            branchlimit => $branchlimit,
            itemtypeslimit => $itemtypeslimit,
            ccodeslimit => $ccodeslimit,
            locationslimit => $locationslimit
        });
        
        # for my $item ( @$items ) {
        #     $item->{patron} = Koha::Patrons->find( $item->{borrowernumber} );
        # }
        
        $template->param(
            branchlimit     => $branchlimit,
            itemtypeslimit  => $itemtypeslimit,
            ccodeslimit     => $ccodeslimit,
            locationslimit  => $locationslimit,
            total           => $items->count; # scalar @$items,
            itemsloop       => $items,
            run_report      => $run_report,
        );
    }

    # Checking if there is a Fast Cataloging Framework
    $template->param( fast_cataloging => 1 ) if Koha::BiblioFrameworks->find( 'FA' );

    # writing the template
    output_html_with_http_headers $query, $cookie, $template->output;
}
