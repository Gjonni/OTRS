# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# Creato Da Giovanni Filice
# --

package Kernel::Modules::AgentTicketSistemiIT;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";
    $Self->{TicketID} = $Param{TicketID} || die "Got no TicketID!";
    return $Self;
}



sub Run {
    my ( $Self, %Param ) = @_;
	
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
	my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

# check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Non Posso effettuare Escalation'),
            Comment => Translatable('Please contact the admin.'),
        );
    }
	
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

	# check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'rw',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }
        my %PossibleActions = ( 1 => $Self->{Action} );

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {

        my %AclActionLookup = reverse %AclAction;

        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

	
	
	
	my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
		Silent        => 1,

    );	
     
    my $NewTicket = $TicketObject->TicketCreate(
        %Param,
		OwnerID      => 1,
		Queue        => 'Sistemi Informativi',
		Title        => 'Escalation Da HelpDesk',
		Lock         => 'unlock',
		State        => 'new', 
		Priority     => '5 very high',
		CustomerID   => $Ticket{CustomerID},
		UserID            =>   $Self->{UserID},
		Type          => 'Problem',

    );
	if ( !$NewTicket ) {
                return $LayoutObject->ErrorScreen();
            }

	my $Success = $TicketObject->TicketServiceSet(
        Service => 'Sistemi Informativi',
        TicketID  => $NewTicket,
        UserID    => $Self->{UserID},
    );		
		
my $Field1Config = $DynamicFieldObject->DynamicFieldGet(
    Name       => "Escalation",
    Label      => 'Escalation',
    FieldOrder => 9991,
    FieldType  => 'Text',            # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
);

my $Success = $BackendObject->ValueSet(
    DynamicFieldConfig => $Field1Config,
    ObjectID           => $NewTicket,
    Value              => 'Si',
    UserID             => $Self->{UserID},
);

my $Success = $BackendObject->ValueSet(
    DynamicFieldConfig => $Field1Config,
    ObjectID           => $Self->{TicketID},
    Value              => 'Si',
    UserID             => $Self->{UserID},
);
			
			
			
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Self->{TicketID},
        Extended      => 1,      
        DynamicFields => 1,      
    );
    
	 my $ParentArticle = $TicketObject->ArticleCreate(
        %Param,
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
	    ArticleType      => 'note-external',
	    SenderType       => 'agent', 
	    ContentType      => 'text/plain; charset=ISO-8859-15',
        Body             => 'Il ticket è stato scalato a Sistemi Informativi',                
        HistoryType      => 'Forward',                         
        HistoryComment   => 'Some free text!',
	    From             => 'Sistema OTRS',
	    Subject          => 'Il ticket è stato scalato a Sistemi Informativi',  
		
    );
	if ( !$ParentArticle ) {
                return $LayoutObject->ErrorScreen();
            }
	
	
	
    my $ChildArticle = $TicketObject->ArticleCreate(
    %Param,
    TicketID => $NewTicket,
    UserID   => $Self->{UserID},
	ArticleType      => 'email-internal',
	SenderType       => 'agent', 
	ContentType      => 'text/plain; charset=ISO-8859-15',
    Body             => $Article{Body},                
    HistoryType      => 'Forward',                         
    HistoryComment   => 'Some free text!',
	From             => $Article{CustomerID},
	Subject          => $Article{Subject},
       
		
    );
	if ( !$ChildArticle ) {
                return $LayoutObject->ErrorScreen();
            }


	my $Success = $TicketObject->TicketPendingTimeSet(
        Diff     => ( 1 * 24 * 60 ),  # minutes (here: 10080 minutes - 7 days)
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );

	my $Success = $TicketObject->TicketStateSet(
        State        => 'Pending Escalation Internal', 
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );
     
	 
        $LinkObject->LinkAdd(
        SourceObject => 'Ticket',
        SourceKey    => $Self->{TicketID},
        TargetObject => 'Ticket',
        TargetKey    => $NewTicket,
        Type         => 'ParentChild',
        State        => 'Valid',
        UserID       => 1,
		Direction => 'Source',  
    );
        
   
   return $LayoutObject->PopupClose(
              URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$Self->{ArticleID}",
          );
	
}

1;
