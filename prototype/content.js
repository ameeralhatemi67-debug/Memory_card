// Memory Card prototype — starter content.
// Each pool is one deck's cards, one per line: front | back | label | example (label and example optional).
// `kind: 'code'` sets the front in a monospace face; `lang` drives "Hear it" (speech synthesis).

export const POOLS = {
  de_a1: { lang: 'de-DE', tag: 'noun', rows: `
das Eichhörnchen | the squirrel | noun · neuter | Das Eichhörnchen versteckt Nüsse im Garten.
die Brücke | the bridge | noun · feminine | Wir gehen über die alte Brücke.
der Schmetterling | the butterfly | noun · masculine | Ein Schmetterling sitzt auf der Blume.
die Zeitung | the newspaper | noun · feminine | Mein Opa liest jeden Morgen die Zeitung.
das Frühstück | breakfast | noun · neuter | Das Frühstück ist um acht Uhr fertig.
der Regenschirm | the umbrella | noun · masculine | Vergiss deinen Regenschirm nicht!
die Gurke | the cucumber | noun · feminine | Die Gurke ist frisch und grün.
das Gewitter | the thunderstorm | noun · neuter | Heute Abend kommt ein Gewitter.
der Bahnhof | the train station | noun · masculine | Der Bahnhof ist nicht weit von hier.
die Kartoffel | the potato | noun · feminine | Wir essen Kartoffeln mit Quark.
das Fahrrad | the bicycle | noun · neuter | Ich fahre mit dem Fahrrad zur Arbeit.
der Schlüssel | the key | noun · masculine | Wo ist mein Schlüssel?
die Wolke | the cloud | noun · feminine | Am Himmel ist keine Wolke.
das Geschenk | the gift | noun · neuter | Das Geschenk ist für dich.
der Kühlschrank | the fridge | noun · masculine | Die Milch steht im Kühlschrank.
die Treppe | the stairs | noun · feminine | Die Treppe ist sehr steil.
das Fenster | the window | noun · neuter | Mach bitte das Fenster zu.
der Löffel | the spoon | noun · masculine | Ich brauche einen Löffel für die Suppe.
die Rechnung | the bill | noun · feminine | Die Rechnung, bitte!
das Handy | the mobile phone | noun · neuter | Mein Handy ist leer.
der Nachbar | the neighbour | noun · masculine | Unser Nachbar hat einen Hund.
die Ampel | the traffic light | noun · feminine | Die Ampel ist rot.
das Kissen | the pillow | noun · neuter | Das Kissen ist weich.
der Wecker | the alarm clock | noun · masculine | Der Wecker klingelt um sechs.` },

  de_basics: { lang: 'de-DE', tag: 'word', rows: `
der Apfel | the apple | noun · masculine | Ich esse jeden Tag einen Apfel.
die Birne | the pear | noun · feminine | Die Birne ist süß.
die Milch | the milk | noun · feminine | Die Milch ist kalt.
das Brot | the bread | noun · neuter | Das Brot ist frisch.
die Butter | the butter | noun · feminine | Ich brauche noch Butter.
das Wasser | the water | noun · neuter | Ein Glas Wasser, bitte.
der Tisch | the table | noun · masculine | Das Buch liegt auf dem Tisch.
der Stuhl | the chair | noun · masculine | Der Stuhl ist bequem.
das Haus | the house | noun · neuter | Das Haus ist groß.
die Tür | the door | noun · feminine | Die Tür ist offen.
die Stadt | the city | noun · feminine | Berlin ist eine große Stadt.
der Hund | the dog | noun · masculine | Der Hund spielt im Park.
die Katze | the cat | noun · feminine | Die Katze schläft.
das Auto | the car | noun · neuter | Das Auto ist neu.
gehen | to go, to walk | verb | Wir gehen nach Hause.
kommen | to come | verb | Kommst du mit?
essen | to eat | verb | Was isst du gern?
trinken | to drink | verb | Ich trinke Tee.
schlafen | to sleep | verb | Das Baby schläft.
sprechen | to speak | verb | Sprechen Sie Englisch?
heute | today | adverb | Heute ist Montag.
morgen | tomorrow | adverb | Bis morgen!
groß | big, tall | adjective | Mein Bruder ist groß.
klein | small | adjective | Die Wohnung ist klein.` },

  de_a2: { lang: 'de-DE', tag: 'word', rows: `
die Erfahrung | the experience | noun · feminine | Das war eine gute Erfahrung.
der Termin | the appointment | noun · masculine | Ich habe morgen einen Termin beim Arzt.
die Umgebung | the surroundings | noun · feminine | Die Umgebung ist sehr ruhig.
sich erinnern | to remember | verb | Ich erinnere mich an den Urlaub.
sich beschweren | to complain | verb | Er beschwert sich über den Lärm.
vorschlagen | to suggest | verb | Ich schlage vor, wir gehen ins Kino.
die Gelegenheit | the opportunity | noun · feminine | Das ist eine gute Gelegenheit.
der Vertrag | the contract | noun · masculine | Lies den Vertrag genau.
pünktlich | on time | adjective | Der Zug ist heute pünktlich.
gemütlich | cosy | adjective | Das Café ist sehr gemütlich.
die Wohnung | the flat | noun · feminine | Wir suchen eine neue Wohnung.
die Ausbildung | the vocational training | noun · feminine | Sie macht eine Ausbildung als Köchin.
verschieben | to postpone | verb | Wir müssen das Treffen verschieben.
das Gehalt | the salary | noun · neuter | Das Gehalt kommt am Monatsende.
ausgezeichnet | excellent | adjective | Das Essen war ausgezeichnet.
die Erlaubnis | the permission | noun · feminine | Du brauchst eine Erlaubnis.` },

  de_b1: { lang: 'de-DE', tag: 'word', rows: `
die Voraussetzung | the prerequisite | noun · feminine | Deutschkenntnisse sind eine Voraussetzung.
die Auswirkung | the effect | noun · feminine | Das hat Auswirkungen auf die Umwelt.
nachhaltig | sustainable | adjective | Wir wollen nachhaltiger leben.
der Zusammenhang | the connection, context | noun · masculine | In diesem Zusammenhang ist das wichtig.
die Herausforderung | the challenge | noun · feminine | Das ist eine große Herausforderung.
berücksichtigen | to take into account | verb | Bitte berücksichtigen Sie die Kosten.
der Vorteil | the advantage | noun · masculine | Ein Vorteil ist der Preis.
der Nachteil | the disadvantage | noun · masculine | Der Nachteil ist die Entfernung.
überzeugen | to convince | verb | Das Argument hat mich überzeugt.
die Gewohnheit | the habit | noun · feminine | Das ist eine schlechte Gewohnheit.
sich bewerben um | to apply for | verb | Sie bewirbt sich um die Stelle.
die Umfrage | the survey | noun · feminine | Laut einer Umfrage lesen viele weniger.
vermeiden | to avoid | verb | Wir sollten Plastik vermeiden.
die Rücksicht | consideration | noun · feminine | Nimm Rücksicht auf die anderen.
ehrenamtlich | voluntary, unpaid | adjective | Er arbeitet ehrenamtlich im Verein.
die Verantwortung | the responsibility | noun · feminine | Sie trägt viel Verantwortung.` },

  de_num: { lang: 'de-DE', tag: 'number', rows: `
eins | one | number
zwei | two | number
drei | three | number
vier | four | number
fünf | five | number
sechs | six | number
sieben | seven | number
acht | eight | number
neun | nine | number
zehn | ten | number
elf | eleven | number
zwölf | twelve | number
zwanzig | twenty | number
einundzwanzig | twenty-one | number
hundert | one hundred | number
tausend | one thousand | number` },

  de_verbs: { lang: 'de-DE', tag: 'verb', rows: `
machen | to make, to do | verb | Was machst du heute?
haben | to have | verb | Ich habe keine Zeit.
sein | to be | verb | Wir sind müde.
werden | to become | verb | Es wird kalt.
können | can, to be able to | verb · modal | Kannst du schwimmen?
müssen | must, to have to | verb · modal | Ich muss jetzt gehen.
wollen | to want | verb · modal | Sie will Ärztin werden.
sagen | to say | verb | Was sagst du?
fragen | to ask | verb | Darf ich etwas fragen?
antworten | to answer | verb | Er antwortet nicht.
kaufen | to buy | verb | Ich kaufe Brot.
bezahlen | to pay | verb | Kann ich mit Karte bezahlen?
arbeiten | to work | verb | Sie arbeitet in Hamburg.
wohnen | to live (reside) | verb | Wo wohnst du?
lernen | to learn | verb | Ich lerne Deutsch.
vergessen | to forget | verb | Ich habe es vergessen.` },

  es_basics: { lang: 'es-ES', tag: 'word', rows: `
el perro | the dog | noun · masculine | El perro duerme en el sofá.
el gato | the cat | noun · masculine | El gato bebe leche.
la casa | the house | noun · feminine | Mi casa es tu casa.
el agua | the water | noun · feminine | El agua está fría.
la mesa | the table | noun · feminine | La comida está en la mesa.
la silla | the chair | noun · feminine | La silla es nueva.
el libro | the book | noun · masculine | Leo un libro cada mes.
la ventana | the window | noun · feminine | Abre la ventana, por favor.
la puerta | the door | noun · feminine | La puerta está cerrada.
el coche | the car | noun · masculine | Mi coche es rojo.
la ciudad | the city | noun · feminine | Madrid es una ciudad grande.
el trabajo | the work, the job | noun · masculine | Voy al trabajo en metro.
la playa | the beach | noun · feminine | Vamos a la playa.
el dinero | the money | noun · masculine | No tengo dinero.
la comida | the food | noun · feminine | La comida está rica.
el desayuno | breakfast | noun · masculine | El desayuno es a las ocho.
hola | hello | greeting
gracias | thank you | phrase
por favor | please | phrase
lo siento | I'm sorry | phrase
hoy | today | adverb | Hoy hace sol.
mañana | tomorrow | adverb | Hasta mañana.
grande | big | adjective | Es un perro grande.
pequeño | small | adjective | El piso es pequeño.` },

  es_verbs: { lang: 'es-ES', tag: 'verb', rows: `
hablar | to speak | verb | Hablo un poco de español.
comer | to eat | verb | Comemos a las dos.
vivir | to live | verb | Vivo en Sevilla.
ser | to be (lasting) | verb | Soy profesora.
estar | to be (state, place) | verb | Estoy cansado.
tener | to have | verb | Tengo dos hermanos.
hacer | to do, to make | verb | ¿Qué haces?
ir | to go | verb | Voy al mercado.
venir | to come | verb | ¿Vienes conmigo?
poder | can, to be able to | verb | ¿Puedo pasar?
querer | to want, to love | verb | Quiero un café.
saber | to know (facts) | verb | No sé la respuesta.
conocer | to know (people, places) | verb | Conozco a tu hermano.
decir | to say | verb | ¿Qué dices?
ver | to see | verb | Veo el mar.
dar | to give | verb | Te doy mi número.
salir | to go out | verb | Salimos esta noche.
volver | to return | verb | Vuelvo a las seis.
pensar | to think | verb | Pienso que sí.
dormir | to sleep | verb | Duermo ocho horas.` },

  fr_ess: { lang: 'fr-FR', tag: 'word', rows: `
bonjour | hello, good morning | greeting
merci | thank you | phrase
s'il vous plaît | please (formal) | phrase
excusez-moi | excuse me | phrase
la maison | the house | noun · feminine | La maison est grande.
le livre | the book | noun · masculine | Ce livre est passionnant.
la voiture | the car | noun · feminine | La voiture est garée devant.
le travail | work | noun · masculine | Je vais au travail à pied.
l'école | the school | noun · feminine | L'école commence à huit heures.
la gare | the train station | noun · feminine | La gare est près d'ici.
le jour | the day | noun · masculine | C'est un beau jour.
la nuit | the night | noun · feminine | Bonne nuit !
aujourd'hui | today | adverb | Aujourd'hui, il pleut.
demain | tomorrow | adverb | À demain !
hier | yesterday | adverb | Hier, j'étais malade.
toujours | always | adverb | Il est toujours en retard.
parler | to speak | verb | Vous parlez anglais ?
aller | to go | verb | On va au cinéma.
avoir | to have | verb | J'ai faim.
être | to be | verb | Nous sommes prêts.` },

  fr_food: { lang: 'fr-FR', tag: 'food', rows: `
le pain | bread | noun · masculine | Une baguette de pain, s'il vous plaît.
le fromage | cheese | noun · masculine | La France a beaucoup de fromages.
la pomme | the apple | noun · feminine | Je mange une pomme.
le beurre | butter | noun · masculine | Du pain avec du beurre.
le poulet | chicken | noun · masculine | Le poulet est rôti.
le poisson | fish | noun · masculine | Le poisson est frais.
la viande | meat | noun · feminine | Je ne mange pas de viande.
les légumes | vegetables | noun · masculine plural | Mange tes légumes !
la fraise | the strawberry | noun · feminine | Une tarte aux fraises.
le lait | milk | noun · masculine | Un café au lait.
l'œuf | the egg | noun · masculine | Un œuf à la coque.
le sel | salt | noun · masculine | Passe-moi le sel.
le sucre | sugar | noun · masculine | Sans sucre, merci.
la soupe | soup | noun · feminine | La soupe est chaude.
le gâteau | the cake | noun · masculine | Le gâteau au chocolat.
l'addition | the bill | noun · feminine | L'addition, s'il vous plaît.` },

  ar_alpha: { lang: 'ar-SA', tag: 'letter', rows: `
ا | alif · a, ā | letter
ب | bāʾ · b | letter
ت | tāʾ · t | letter
ث | thāʾ · th as in think | letter
ج | jīm · j | letter
ح | ḥāʾ · breathy h | letter
خ | khāʾ · kh as in Bach | letter
د | dāl · d | letter
ذ | dhāl · th as in this | letter
ر | rāʾ · rolled r | letter
ز | zāy · z | letter
س | sīn · s | letter
ش | shīn · sh | letter
ص | ṣād · heavy s | letter
ض | ḍād · heavy d | letter
ط | ṭāʾ · heavy t | letter
ظ | ẓāʾ · heavy th | letter
ع | ʿayn · throat sound | letter
غ | ghayn · gargled g | letter
ف | fāʾ · f | letter
ق | qāf · deep k | letter
ك | kāf · k | letter
ل | lām · l | letter
م | mīm · m | letter
ن | nūn · n | letter
ه | hāʾ · h | letter
و | wāw · w, ū | letter
ي | yāʾ · y, ī | letter` },

  ar_greet: { lang: 'ar-SA', tag: 'phrase', rows: `
مرحبا | hello · marḥaban | greeting
السلام عليكم | peace be upon you · as-salāmu ʿalaykum | greeting
وعليكم السلام | and upon you peace · wa ʿalaykum as-salām | reply
صباح الخير | good morning · ṣabāḥ al-khayr | greeting
صباح النور | good morning (reply) · ṣabāḥ an-nūr | reply
مساء الخير | good evening · masāʾ al-khayr | greeting
شكرا | thank you · shukran | phrase
عفوا | you're welcome · ʿafwan | phrase
كيف حالك؟ | how are you? · kayfa ḥāluk | question
أنا بخير | I'm fine · anā bikhayr | reply
مع السلامة | goodbye · maʿa as-salāma | greeting
من فضلك | please · min faḍlak | phrase` },

  en_idioms: { lang: 'en-GB', tag: 'idiom', rows: `
break the ice | ease the first awkward moment | idiom | A joke helped break the ice.
a piece of cake | very easy | idiom | The exam was a piece of cake.
hit the sack | go to bed | idiom | I'm going to hit the sack.
under the weather | feeling ill | idiom | She's a bit under the weather.
spill the beans | reveal a secret | idiom | Who spilled the beans?
cost an arm and a leg | be very expensive | idiom | That car cost an arm and a leg.
once in a blue moon | very rarely | idiom | We eat out once in a blue moon.
bite the bullet | face something unpleasant | idiom | I bit the bullet and called him.
let the cat out of the bag | reveal a secret by mistake | idiom | He let the cat out of the bag.
the ball is in your court | it's your decision now | idiom | I've made my offer; the ball is in your court.
call it a day | stop working for now | idiom | Let's call it a day.
on the fence | undecided | idiom | I'm still on the fence about it.
cut corners | do it badly to save time | idiom | Don't cut corners on safety.
beat around the bush | avoid the main point | idiom | Stop beating around the bush.
miss the boat | lose a chance | idiom | Tickets sold out; we missed the boat.
a blessing in disguise | a good thing that seemed bad | idiom | Losing that job was a blessing in disguise.` },

  py: { kind: 'code', tag: 'python', rows: `
len(x) | number of items in x | python
range(5) | 0, 1, 2, 3, 4 | python
xs.append(x) | add x to the end of a list | python
"a,b".split(",") | ['a', 'b'] | python
", ".join(items) | join strings with ", " between them | python
d.get(k, default) | value for k, or default if k is missing | python
[x*2 for x in xs] | a new list with every item doubled | python
lambda x: x + 1 | a small anonymous function | python
with open(p) as f: | open a file and close it automatically | python
except ValueError: | catch a ValueError raised in try | python
f"{name}!" | f-string: puts name into the text | python
a is b | true when a and b are the same object | python
*args | extra positional arguments, as a tuple | python
**kwargs | extra keyword arguments, as a dict | python` },

  git: { kind: 'code', tag: 'git', rows: `
git status | show changed and staged files | git
git add -p | stage changes hunk by hunk | git
git commit --amend | rewrite the last commit | git
git log --oneline | one line per commit | git
git diff --staged | show what is staged | git
git switch -c name | create a branch and switch to it | git
git stash | shelve uncommitted changes | git
git stash pop | bring shelved changes back | git
git rebase main | replay your commits on top of main | git
git merge --no-ff | merge, always creating a merge commit | git
git reset --soft HEAD~1 | undo the last commit, keep changes staged | git
git restore file | discard changes in a file | git
git fetch | download remote changes without merging | git
git cherry-pick <sha> | apply one commit onto this branch | git` },

  dart: { kind: 'code', tag: 'dart', rows: `
final vs const | set once at runtime vs fixed at compile time | dart
String? name | a String that may be null | dart
name ?? 'Guest' | 'Guest' when name is null | dart
name! | assert that name is not null | dart
late | initialise later, before first use | dart
=> expr | arrow function that returns expr | dart
List<int> xs = [1, 2]; | a typed list | dart
Map<String, int> | a map from String keys to int values | dart
async / await | write asynchronous code top to bottom | dart
Future<T> | a value that arrives later | dart
Stream<T> | many values over time | dart
extends vs implements | inherit code vs promise an interface | dart` },

  cpp: { kind: 'code', tag: 'c++', rows: `
int* p = &x; | p holds the address of x | c++
*p | dereference: the value p points to | c++
&x | the address of x | c++
nullptr | a pointer that points to nothing | c++
p->field | a member reached through a pointer | c++
new int(5) | allocate an int on the heap | c++
delete p; | free memory allocated with new | c++
int& r = x; | r is a reference (alias) to x | c++
std::unique_ptr<T> | sole owner; frees memory automatically | c++
std::shared_ptr<T> | shared ownership, reference-counted | c++
const int* p | pointer to a constant int | c++
int* const p | constant pointer to an int | c++` },

  bones: { tag: 'bone', rows: `
femur | thigh bone, the longest in the body | bone
tibia | shin bone | bone
fibula | thin bone beside the tibia | bone
patella | kneecap | bone
humerus | upper arm bone | bone
radius | forearm bone on the thumb side | bone
ulna | forearm bone on the little-finger side | bone
clavicle | collarbone | bone
scapula | shoulder blade | bone
sternum | breastbone | bone
mandible | lower jaw | bone
vertebrae | the bones of the spine | bone
pelvis | the hip bones | bone
carpals | the eight wrist bones | bone` },

  pharm: { tag: 'drug class', rows: `
-pril | ACE inhibitor: lowers blood pressure (lisinopril) | drug class
-olol | beta blocker: slows the heart (metoprolol) | drug class
-statin | lowers cholesterol (atorvastatin) | drug class
-prazole | proton pump inhibitor: less stomach acid (omeprazole) | drug class
NSAIDs | pain and inflammation (ibuprofen) | drug class
SSRIs | depression and anxiety (sertraline) | drug class
-azepam | benzodiazepine: anxiety, sedation (diazepam) | drug class
loop diuretics | remove fluid (furosemide) | drug class
anticoagulants | prevent clots (warfarin) | drug class
-cillin | penicillin antibiotic (amoxicillin) | drug class
opioids | strong pain relief (morphine) | drug class
antihistamines | allergy relief (cetirizine) | drug class` },

  medpre: { tag: 'prefix', rows: `
brady- | slow | prefix | bradycardia
tachy- | fast | prefix | tachycardia
hyper- | above, too much | prefix | hypertension
hypo- | below, too little | prefix | hypoglycaemia
cardio- | heart | prefix | cardiology
hepato- | liver | prefix | hepatitis
nephro- | kidney | prefix | nephrology
neuro- | nerve | prefix | neuropathy
osteo- | bone | prefix | osteoporosis
derm- | skin | prefix | dermatitis
gastro- | stomach | prefix | gastroenteritis
-itis | inflammation | suffix | tonsillitis` },

  capitals: { tag: 'country', rows: `
Australia | Canberra | country
Canada | Ottawa | country
Brazil | Brasília | country
Turkey | Ankara | country
Switzerland | Bern | country
New Zealand | Wellington | country
Morocco | Rabat | country
Nigeria | Abuja | country
Pakistan | Islamabad | country
Vietnam | Hanoi | country
Egypt | Cairo | country
Kenya | Nairobi | country
Argentina | Buenos Aires | country
Norway | Oslo | country
South Korea | Seoul | country
Peru | Lima | country
Iraq | Baghdad | country
Jordan | Amman | country
Portugal | Lisbon | country
Thailand | Bangkok | country` },

  elements: { tag: 'element', rows: `
H | hydrogen · 1 | element
He | helium · 2 | element
C | carbon · 6 | element
N | nitrogen · 7 | element
O | oxygen · 8 | element
Na | sodium · 11 | element
Mg | magnesium · 12 | element
Cl | chlorine · 17 | element
K | potassium · 19 | element
Ca | calcium · 20 | element
Fe | iron · 26 | element
Cu | copper · 29 | element
Ag | silver · 47 | element
Sn | tin · 50 | element
Au | gold · 79 | element
Pb | lead · 82 | element` },

  airport: { lang: 'en-GB', tag: 'travel', rows: `
boarding pass | the pass you show to get on the plane | travel
gate | where you board the plane | travel
aisle seat | the seat next to the corridor | travel
window seat | the seat next to the window | travel
carry-on | the bag you take into the cabin | travel
layover | a stop between two flights | travel
customs | where the goods you bring in are checked | travel
baggage claim | where you collect checked bags | travel
check-in desk | where you drop bags and get a boarding pass | travel
delayed | later than planned | travel
departure lounge | the waiting area after security | travel
jet lag | tiredness after crossing time zones | travel` },

  ja: { lang: 'ja-JP', tag: 'phrase', rows: `
こんにちは | hello · konnichiwa | greeting
ありがとう | thank you · arigatō | phrase
すみません | excuse me, sorry · sumimasen | phrase
はい | yes · hai | word
いいえ | no · iie | word
お願いします | please · onegaishimasu | phrase
いくらですか | how much is it? · ikura desu ka | question
トイレはどこですか | where is the toilet? · toire wa doko desu ka | question
駅 | station · eki | noun
水 | water · mizu | noun
おいしい | delicious · oishii | adjective
さようなら | goodbye · sayōnara | greeting` },

  hist: { tag: 'date', rows: `
Fall of the Western Roman Empire | 476 | date
Battle of Hastings | 1066 | date
Magna Carta sealed | 1215 | date
Gutenberg's printing press | around 1440 | date
Columbus reaches the Americas | 1492 | date
Start of the French Revolution | 1789 | date
Battle of Waterloo | 1815 | date
Start of World War I | 1914 | date
Start of World War II | 1939 | date
End of World War II | 1945 | date
First Moon landing | 1969 | date
Fall of the Berlin Wall | 1989 | date
Euro notes and coins introduced | 2002 | date
First iPhone released | 2007 | date` },

  ancient: { tag: 'date', rows: `
Rome founded (legend) | 753 BC | date
Battle of Marathon | 490 BC | date
Death of Alexander the Great | 323 BC | date
Qin Shi Huang unifies China | 221 BC | date
Julius Caesar assassinated | 44 BC | date
Augustus becomes emperor | 27 BC | date
Vesuvius buries Pompeii | AD 79 | date
Hadrian's Wall begun | AD 122 | date
Constantinople founded | AD 330 | date
Code of Hammurabi | around 1754 BC | date` },

  chords: { tag: 'chord', rows: `
C major | x32010 | chord
G major | 320003 | chord
D major | xx0232 | chord
A minor | x02210 | chord
E minor | 022000 | chord
E major | 022100 | chord
A major | x02220 | chord
F major (barre) | 133211 | chord
D minor | xx0231 | chord
C7 | x32310 | chord` },

  morse: { tag: 'morse', rows: `
A | · − | letter
B | − · · · | letter
C | − · − · | letter
D | − · · | letter
E | · | letter
I | · · | letter
N | − · | letter
O | − − − | letter
S | · · · | letter
T | − | letter` }
};

// The user's library at first launch. Deck tuple: [name, pool, slipping, never-studied, days since last studied].
export const LIBRARY = [
  { id: 'f-lang', name: 'Languages', decks: [
    ['Spanish · Basics', 'es_basics', 6, 0, 1], ['Spanish · Verbs', 'es_verbs', 7, 2, 1], ['French · Essentials', 'fr_ess', 4, 0, 1],
    ['French · Food', 'fr_food', 0, 0, 3], ['Arabic · Alphabet', 'ar_alpha', 7, 4, 1], ['Arabic · Greetings', 'ar_greet', 5, 2, 3],
    ['English · Idioms', 'en_idioms', 0, 3, 1]] },
  { id: 'f-de', name: 'German', decks: [
    ['German · A1 Everyday', 'de_a1', 6, 4, 1], ['German · Numbers', 'de_num', 1, 0, 1], ['German · Verbs', 'de_verbs', 5, 0, 2]] },
  { id: 'f-code', name: 'Coding', decks: [
    ['Python · Syntax', 'py', 3, 0, 1], ['Git · Commands', 'git', 4, 2, 1], ['Dart · Basics', 'dart', 2, 6, 1]] },
  { id: 'f-med', name: 'Medicine', decks: [
    ['Anatomy · Bones', 'bones', 3, 0, 2], ['Pharmacology · Basics', 'pharm', 5, 2, 2], ['Medical Prefixes', 'medpre', 1, 0, 2]] },
  { id: 'f-exam', name: 'Exam Prep', decks: [['World Capitals', 'capitals', 4, 0, 1], ['Periodic Table', 'elements', 2, 3, 1]] },
  { id: 'f-travel', name: 'Travel', decks: [['Airport English', 'airport', 1, 0, 4], ['Japanese · Survival', 'ja', 4, 2, 4]] },
  { id: 'f-hist', name: 'History', decks: [['History · Key Dates', 'hist', 3, 0, 5], ['History · Ancient World', 'ancient', 4, 0, 5]] },
  { id: 'f-bio', name: 'Biology', decks: [] },
  { id: 'f-archive', name: 'Archive', decks: [['Guitar · Chords', 'chords', 2, 0, 30], ['Morse Code', 'morse', 3, 0, 40]] }
];

// The shop catalogue (design: Shop.dc.html). `pool` is the content the deck brings when added.
export const SHOP_CATS = [
  { id: 'lang', name: 'Languages', dot: '#80AEFF' },
  { id: 'code', name: 'Coding', dot: '#FFC680' },
  { id: 'med', name: 'Medicine', dot: '#D35F5F' }
];
export const SHOP = [
  { id: 's-de-a1', mono: 'De', name: 'German · A1 Basics', pool: 'de_basics', cat: 'lang', level: 'A1', home: 'German',
    desc: 'The everyday nouns, verbs and adjectives you meet first, each with an example sentence and pronunciation.' },
  { id: 's-de-a2', mono: 'De', name: 'German · A2', pool: 'de_a2', cat: 'lang', level: 'A2', home: 'German',
    desc: 'Words for appointments, flats, work and complaints: the vocabulary of getting things done.' },
  { id: 's-de-b1', mono: 'De', name: 'German · B1', pool: 'de_b1', cat: 'lang', level: 'B1', home: 'German',
    desc: 'Abstract words for arguing a point: advantages, effects, habits and responsibilities.' },
  { id: 's-es', mono: 'Es', name: 'Spanish · Basics', pool: 'es_basics', cat: 'lang', level: 'A1', home: 'Languages',
    desc: 'Home, food, city and the phrases you need on day one, with example sentences.' },
  { id: 's-fr', mono: 'Fr', name: 'French · Essentials', pool: 'fr_ess', cat: 'lang', level: 'A1', home: 'Languages',
    desc: 'Greetings, time words and the four verbs everything else is built on.' },
  { id: 's-ar', mono: 'ع', name: 'Arabic · Alphabet', pool: 'ar_alpha', cat: 'lang', level: 'script', home: 'Languages',
    desc: 'All 28 letters with their names and sounds, including the heavy consonants.' },
  { id: 's-en', mono: 'En', name: 'English · Idioms', pool: 'en_idioms', cat: 'lang', level: 'B2', home: 'Languages',
    desc: 'Sixteen idioms native speakers use every week, each in a real sentence.' },
  { id: 's-py', mono: 'Py', name: 'Python · Syntax', pool: 'py', cat: 'code', level: 'basics', home: 'Coding',
    desc: 'The built-ins and syntax you look up most: slicing, comprehensions, context managers.' },
  { id: 's-dart', mono: 'Da', name: 'Dart · Basics', pool: 'dart', cat: 'code', level: 'basics', home: 'Coding',
    desc: 'Null safety, futures and the type system: what you need before writing Flutter.' },
  { id: 's-cpp', mono: 'C++', name: 'C++ · Pointers', pool: 'cpp', cat: 'code', level: 'core', home: 'Coding',
    desc: 'Addresses, references and smart pointers, one idea per card.' },
  { id: 's-bones', mono: 'Bo', name: 'Anatomy · Bones', pool: 'bones', cat: 'med', level: 'skeleton', home: 'Medicine',
    desc: 'The major bones of the skeleton with their everyday names.' },
  { id: 's-rx', mono: 'Rx', name: 'Pharmacology · Basics', pool: 'pharm', cat: 'med', level: 'drug classes', home: 'Medicine',
    desc: 'Recognise a drug class from its name ending, with one example each.' }
];
