# --
# Kernel/System/Ticket/Event/UpdateToParent.pm - event module
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information.
# --

package Kernel::System::Ticket::Event::UpdateToParent;

use strict;
use warnings;


use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
 my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );

            return;
        }
    }
    if ( !$Param{Data}->{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Data->{TicketID}!"
        );

        return;
    }
   
   

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

     # get ticket attributes
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 1,
    );
    my $EscalationDynamicField = $ConfigObject->Get('Escalation::DynamicField');
    return 1 if $Ticket{ 'DynamicField_' . $EscalationDynamicField };

   if ( $Param{Event} eq 'ArticleCreate' ) { 
        my @Index = $TicketObject->ArticleIndex( TicketID => $Param{Data}->{TicketID} );

        return 1 if !@Index;

        my %Article = $TicketObject->ArticleGet( ArticleID => $Index[-1] );
        
        my %ChildToParent = $LinkObject->LinkKeyListWithData(
         Object1  => 'Ticket',
         Key1      => $Param{Data}->{TicketID}, #current TicketID
         Object2   => 'Ticket',
         Type      => 'ParentChild',
         Direction => 'Source',
         State     => 'Valid',
         UserID    => $Param{UserID},
      );
    
		 
		if (%ChildToParent)  {
		for my $ParentTicketID ( keys %ChildToParent ) {
		
            my %ParentTicket = $TicketObject->TicketGet(
               TicketID => $ParentTicketID,
               DynamicFields => 1,
               UserID   => 1,
            );  
		
		$TicketObject->ArticleCreate(
        %Article,
        TicketID => $ParentTicketID, 
	UserID   => $Param{UserID},
	HistoryType    => 'AddNote',
        HistoryComment => 'Added article based on Child ticket.',
		
						            );
	my $Success = $TicketObject->TicketStateSet(
        State => 'Pending Escalation Internal',
        TicketID => $ParentTicketID, 
        UserID   => $Param{UserID},
					                );								
					
					} 
	    
	
				}


	
	
	
	
		 
    }
    
	 if ( $Param{Event} eq 'TicketStateClose' ) { 
        my @Index = $TicketObject->ArticleIndex( TicketID => $Param{Data}->{TicketID} );

        return 1 if !@Index;

        my %Article = $TicketObject->ArticleGet( ArticleID => $Index[-1] );
        
        my %ChildToParent = $LinkObject->LinkKeyListWithData(
         Object1  => 'Ticket',
         Key1      => $Param{Data}->{TicketID}, #current TicketID
         Object2   => 'Ticket',
         Type      => 'ParentChild',
         Direction => 'Source',
         State     => 'Valid',
         UserID    => $Param{UserID},
      );
    
		 
		if (%ChildToParent)  {
		for my $ParentTicketID ( keys %ChildToParent ) {
		
            my %ParentTicket = $TicketObject->TicketGet(
               TicketID => $ParentTicketID,
               DynamicFields => 1,
               UserID   => 1,
            );  
		
		$TicketObject->ArticleCreate(
        %Article,
        TicketID => $ParentTicketID, 
		UserID   => $Param{UserID},
		HistoryType    => 'AddNote',
        HistoryComment => 'Added article based on Child ticket.',
		
					);
	my $Success = $TicketObject->TicketStateSet(
        StateID  => 'open',
        TicketID => $ParentTicketID, 
        UserID   => $Param{UserID},
					);				
				} 
	    
	
			}

         
	
	
	
	
		 
		}
	
	
	
	
	
	
	
	}
		
1;
