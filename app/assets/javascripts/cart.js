$(document).on('turbolinks:load',function() {
  // a typeahead that adds people to the card.
  // interacts with cocoon to do nested forms
  // does both big and mini-cart

  added_person = {};

    // initialize bloodhound engine
  var searchSelector = 'input#cart-typeahead';

  //filters out tags that are already in the list
  var filter = function(suggestions) {9
    var current_people = $('.cart-container tr').map(function(index,el){
      return Number(el.id.replace(/^(cart-)/,''));
    }).get();
    return $.grep(suggestions, function(suggestion) {
      return $.inArray(suggestion.id,current_people) === -1;
    });
  };

  var bloodhound = new Bloodhound({
    datumTokenizer: function (d) {
      return Bloodhound.tokenizers.whitespace(d.value);
    },
    queryTokenizer: Bloodhound.tokenizers.whitespace,
    remote: {
      url:'/search/index_ransack.json?q[nav_bar_search_cont]=%QUERY',
      wildcard: '%QUERY',
      filter: filter,
      limit: 20,
      cache: false
    }
  });
  bloodhound.initialize();

  // initialize typeahead widget and hook it up to bloodhound engine
  // #typeahead is just a text input
  $(searchSelector).typeahead(null, {
    name: 'People',
    displayKey: 'name',
    source: bloodhound.ttAdapter()
  });

  $(searchSelector).on('typeahead:selected', function(obj, datum){ //datum
    var cart_type = 'full';
    if ($('#mini-cart').length != 0) {
      cart_type = 'mini'
    };

    $.ajax({
      url: '/cart/add/' + datum.id,
      data: {type: cart_type },
      dataType: "script",
      success: function() {
        $(searchSelector).val('');
      }
    });
  });


  if ($('#mini-cart').length != 0) {
    // cleanup add buttons
    $( document ).ajaxComplete(function() {
      $.each(get_current_ids(),function(i,id){
        $('#add-'+id.toString()).hide();
      })
    });

    $('#add_all').click(function(e) {
      $(".add-to-session").each(function(i, obj) {
        var id = $(this).data("personid");
        var name = $(this).data("fullname");
        add_person(id,name);
      });
      $(".add-to-session").hide();
      e.preventDefault();
    });

    $('#remove_all').click(function(e) {
      $('.added_person').remove();
      $('.add-to-session').show();
      $('#research_session_people_ids').val('');
      e.preventDefault();     
    });

    $('.add-to-session').on('click', function(e) {
      
      person = {full_name: $(this).data('fullname'),
                        person_id: $(this).data('personid')};
      add_person(person.person_id,person.full_name);
      e.preventDefault();
    });

    function get_current_ids(){
      var contents =  $('#research_session_people_ids').val();
      if (contents !=='' && typeof contents !== "undefined") {
        return contents.split(',');
      }else{
        return [];
      }
    }

    function add_person(id,name){
      var current_ids = get_current_ids();
      if (!current_ids.includes(id.toString())) {
        $('#add-'+id.toString()).hide();
        current_ids.push(id.toString())
        current_ids = current_ids.filter((v, i, a) => (a.indexOf(v) === i && v != "")); 
        
        $('#research_session_people_ids').val(current_ids.join(','));
        // this is an ugly hack, shoudl be a partial that gets rendered.
        $('#people-store').append("<div class='added_person' id='person-"+ id +"'><span class='btn btn-danger btn-mini'>X</span>&nbsp;&nbsp;<span class='person-name'>"+name+"</span></div>")
        $('#person-'+id).on('click',function(){
          remove_person(id);
        })  
      }
      
    }

    function remove_person(id){
      var current_ids = get_current_ids()
      id = id.toString();
      if (current_ids.includes(id)) {
        current_ids = jQuery.grep(current_ids, function(value) {
          return value != id.toString();
        });

        $('#research_session_people_ids').val(current_ids.join(',')); 
        $('#person-'+id.toString()).remove();
        $('#add-'+id.toString()).show();
      }
    }

    // $('form').on('cocoon:before-insert', function(e, insertedItem) {
    //   console.log('cocoon before insert');
    //   console.log(added_person);
    //   var pid = added_person.person_id;
    //   // horrible, horrible hack to prevent duplicates. why?
    //   window.inserted_people = window.inserted_people || [];
    //   if ($.inArray(pid, window.inserted_people) === -1) {
    //     console.log('not already in list');
    //     window.inserted_people.push(pid);
    //   } else {
    //     e.preventDefault();
    //   }
    // });

    // $('form').on('cocoon:after-insert', function(e, inserted_item) {
    //   console.log('cocoon afer insert');
    //   $(inserted_item).find('.person-name').each(function() {
    //     $(this).text(added_person.full_name);
    //   });

    //   $(inserted_item).find('input[type=hidden]').each(function() {
    //     $(this).val(added_person.person_id);
    //     $('.add-to-session#add-' + added_person.person_id).hide();
    //   });
    // });

    // $('form').on('cocoon:before-remove', function(e,removed_item) {
    //   console.log('cocoon before remove');
    //   // horrible hack continues
    //   window.inserted_people = jQuery.grep(window.inserted_people, function(value) {
    //     return value != $(removed_item).find('input[type=hidden]').val();
    //   });

    //   $(removed_item).find('input[type=hidden]').each(function() {
    //     console.log('cocoon removed item');
    //     $('.add-to-session#add-' + $(this).val()).show();
    //   });
    // });
  }


// // this doesn't quite work.
//   if ($('#new_cart').length >0) {
//     console.log('run validator');
//     $("#new_cart form").validate({
//       rules: {
//         "input#name": {
//           required: true,
//           minlength: 3,
//           maxlenght: 30
//           // remote: "/cart/check_name"
//         }
//       }
//     });
//   }


});
