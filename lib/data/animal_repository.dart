import 'package:flutter/material.dart';

class AnimalData {
  final String labelId;      // English label from ML Kit
  final String localName;    // Bulgarian Name
  final String breed;        // Breed (if applicable, else same as name)
  final String description;  // Interesting fact / description
  final bool isRedBook;      // Is in Red Data Book of Bulgaria?
  final IconData icon;       

  AnimalData({
    required this.labelId,
    required this.localName,
    required this.breed,
    required this.description,
    this.isRedBook = false,
    this.icon = Icons.pets,
  });
}

class AnimalRepository {
  // Mapping logic
  static AnimalData getDataForLabel(String label) {
    // Normalize label
    final normalizedLabel = label.toLowerCase();
    
    // --- FARM ANIMALS ---
    if (normalizedLabel.contains('pig') || normalizedLabel.contains('swine') || normalizedLabel.contains('hog')) {
      return AnimalData(
        labelId: label,
        localName: 'Прасе',
        breed: 'Домашно прасе',
        description: 'Прасетата са едни от най-интелигентните домашни животни, по-умни дори от кучетата. Те имат отлично обоняние и могат да намират трюфели.',
        isRedBook: false,
        icon: Icons.pest_control_rodent, // Closest icon
      );
    }

    if (normalizedLabel.contains('cow') || normalizedLabel.contains('cattle') || normalizedLabel.contains('bull') || normalizedLabel.contains('ox')) {
      return AnimalData(
        labelId: label,
        localName: 'Крава / Бик',
        breed: 'Едър рогат добитък',
        description: 'Кравите са социални животни и създават най-добри приятели в стадото. Те могат да спят прави, но сънуват само когато легнат.',
        isRedBook: false,
        icon: Icons.grass, 
      );
    }
    
    if (normalizedLabel.contains('sheep') || normalizedLabel.contains('lamb') || normalizedLabel.contains('ram')) {
      return AnimalData(
        labelId: label,
        localName: 'Овца',
        breed: 'Домашна овца',
        description: 'Овцете имат невероятна памет и могат да разпознават до 50 различни овчи и човешки лица в продължение на години.',
        isRedBook: false,
        icon: Icons.grass, 
      );
    }
    
    if (normalizedLabel.contains('horse') || normalizedLabel.contains('pony') || normalizedLabel.contains('colt') || normalizedLabel.contains('foal')) {
      return AnimalData(
        labelId: label,
        localName: 'Кон',
        breed: 'Домашен кон',
        description: 'Конете могат да спят както легнали, така и прави. Те имат най-големите очи сред всички сухоземни бозайници.',
        isRedBook: false,
        icon: Icons.bedroom_baby_outlined, // Placeholder for rocking horse style
      );
    }
    
    if (normalizedLabel.contains('chicken') || normalizedLabel.contains('hen') || normalizedLabel.contains('rooster')) {
       return AnimalData(
        labelId: label,
        localName: 'Кокошка / Петел',
        breed: 'Домашна птица',
        description: 'Кокошките са най-разпространените птици в света. Те могат да разпознават над 100 различни лица на хора или други животни.',
        isRedBook: false,
        icon: Icons.egg,
      );
    }

    // --- WILD ANIMALS ---
    if (normalizedLabel.contains('giraffe')) {
      return AnimalData(
        labelId: label,
        localName: 'Жираф',
        breed: 'Жираф',
        description: 'Жирафът е най-високото сухоземно животно. Интересен факт: Езикът на жирафа е дълъг до 50 см и е черен на цвят, за да не изгори от слънцето.',
        isRedBook: false,
        icon: Icons.landscape,
      );
    }
    
     if (normalizedLabel.contains('elephant')) {
      return AnimalData(
        labelId: label,
        localName: 'Слон',
        breed: 'Слон',
        description: 'Слоновете са единствените бозайници, които не могат да скачат. Те са изключително емоционални и скърбят за своите мъртви.',
        isRedBook: false,
        icon: Icons.landscape,
      );
    }
    
    if (normalizedLabel.contains('lion')) {
       return AnimalData(
        labelId: label,
        localName: 'Лъв',
        breed: 'Лъв',
        description: 'Лъвският рев може да се чуе на разстояние от 8 километра. Лъвиците са тези, които ловуват най-често за прайда.',
        isRedBook: false,
        icon: Icons.pets,
      );
    }
    
    if (normalizedLabel.contains('tiger')) {
       return AnimalData(
        labelId: label,
        localName: 'Тигър',
        breed: 'Тигър',
        description: 'Шарките на тигъра са като човешките отпечатъци - уникални за всеки индивид. Тигрите са отлични плувци.',
        isRedBook: true, // Generally endangered globally
        icon: Icons.pets,
      );
    }
    
    if (normalizedLabel.contains('monkey') || normalizedLabel.contains('ape') || normalizedLabel.contains('chimp') || normalizedLabel.contains('gorilla')) {
       return AnimalData(
        labelId: label,
        localName: 'Маймуна',
        breed: 'Примат',
        description: 'Маймуните са много интелигентни и социални. Някои видове използват инструменти за хранене и почистване.',
        isRedBook: false,
        icon: Icons.emoji_nature,
      );
    }

    // --- PETS ---
    if (normalizedLabel.contains('dog') || normalizedLabel.contains('puppy')) {
      // Check for specific breeds if matched by substring (naive check, as ML Kit might give specific labels directly)
      String breed = 'Неопределена порода';
      if (normalizedLabel.contains('retriever')) breed = 'Ретрийвър';
      if (normalizedLabel.contains('shepherd')) breed = 'Овчарка';
      if (normalizedLabel.contains('bulldog')) breed = 'Булдог';
      if (normalizedLabel.contains('poodle')) breed = 'Пудел';
      if (normalizedLabel.contains('husky')) breed = 'Хъски';
      
      return AnimalData(
        labelId: label,
        localName: 'Куче',
        breed: breed, 
        description: 'Кучетата имат уникален "отпечатък на носа", точно както човешките пръстови отпечатъци. Тук AI разпозна: ${breed == "Неопределена порода" ? "Куче (общо)" : breed}.',
        isRedBook: false,
        icon: Icons.pets,
      );
    }

    if (normalizedLabel.contains('cat') || normalizedLabel.contains('kitten')) {
      String breed = 'Домашна котка';
      if (normalizedLabel.contains('siamese')) breed = 'Сиамска котка';
      if (normalizedLabel.contains('persian')) breed = 'Персийска котка';
      if (normalizedLabel.contains('sphynx')) breed = 'Сфинкс';
      
      return AnimalData(
        labelId: label,
        localName: 'Котка',
        breed: breed, 
        description: 'Котките могат да издават над 100 различни звука. Те прекарват 70% от живота си в сън.',
        isRedBook: false,
        icon: Icons.cruelty_free,
      );
    }

    if (normalizedLabel.contains('bird') || normalizedLabel.contains('eagle') || normalizedLabel.contains('hawk') || normalizedLabel.contains('parrot') || normalizedLabel.contains('sparrow')) {
       bool isEagle = normalizedLabel.contains('eagle');
       bool isParrot = normalizedLabel.contains('parrot');
       
       String breed = 'Птица';
       if (isEagle) breed = 'Орел';
       if (isParrot) breed = 'Папагал';
       if (normalizedLabel.contains('owl')) breed = 'Бухал';
       if (normalizedLabel.contains('sparrow')) breed = 'Врабче';
       if (normalizedLabel.contains('pigeon')) breed = 'Гълъб';

       return AnimalData(
        labelId: label,
        localName: breed,
        breed: 'Птица', 
        description: isEagle 
            ? 'Царският орел е световно застрашен вид и е включен в Червената книга на България. Той е символ на сила и величие.' 
            : 'Птиците са единствените животни с пера. Някои видове в България са защитени.',
        isRedBook: isEagle, 
        icon: Icons.flight,
      );
    }

    if (normalizedLabel.contains('bear')) {
      return AnimalData(
        labelId: label,
        localName: 'Мечка',
        breed: 'Кафява мечка', 
        description: 'Кафявата мечка е най-едрият хищник в България. Тя е защитен вид от национално значение и е включена в Червената книга.',
        isRedBook: true,
        icon: Icons.forest,
      );
    }
    
    if (normalizedLabel.contains('rabbit') || normalizedLabel.contains('hare')) {
      return AnimalData(
        labelId: label,
        localName: 'Заек',
        breed: 'Заек',
        description: 'Зайците имат почти 360-градусово зрение, което им помага да се пазят от хищници.',
        isRedBook: false,
        icon: Icons.catching_pokemon,
      );
    }

    // Default Fallback
    return AnimalData(
      labelId: label,
      localName: 'Животно ($label)',
      breed: 'Непознат вид', 
      description: 'AI все още се учи! Разпознахме "$label", но нямаме подробна информация на български език за този вид в момента.',
      isRedBook: false,
      icon: Icons.help_outline,
    );
  }
}
