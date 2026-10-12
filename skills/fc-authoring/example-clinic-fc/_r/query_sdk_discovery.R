# Ad-hoc check (R): data product and collection set discovery, head(n), collection-set selection,
# timestamp columns, and opt-in factors for single_valued categoricals.
#
# Requires tagbio R SDK >= 1.1.91 and an engine with single_valued (2.99.34+).
# Run after `bash _shell_scripts/run_server.sh` is up.

library(tagbio)
library(dplyr)

con <- tagConnect(host_url = "http://localhost:8000")
fc  <- tbl(con)

# Discovery: a localhost connection lists itself; the toy has one collection set, Labs.
products <- tagListDataProducts(con)
stopifnot("data product list has the expected columns" =
            all(c("name", "title", "description", "url") %in% names(products)),
          "localhost lists one data product" = nrow(products) == 1)
sets <- tagListCollectionSets(fc)
stopifnot("Labs collection set is listed" = "Labs" %in% sets)
cat("collection sets:", paste(sets, collapse = ", "), "\n")

# head(n): exactly n entities, the same ones for the same seed, a filter is respected.
first  <- fc %>% select(`Encounter ID`) %>% head(3) %>% collect()
again  <- fc %>% select(`Encounter ID`) %>% head(3) %>% collect()
other  <- fc %>% select(`Encounter ID`) %>% head(3, seed = 7) %>% collect()
cardio <- fc %>% filter(Department == "Cardiology") %>% select(Department) %>% head(2) %>% collect()
stopifnot("head(3) returns 3 entities" = nrow(first) == 3,
          "same seed returns the same entities" =
            identical(sort(first$`Encounter ID`), sort(again$`Encounter ID`)),
          "a different seed returns different entities" =
            !identical(sort(first$`Encounter ID`), sort(other$`Encounter ID`)),
          "head() keeps the filter" = nrow(cardio) == 2 && all(cardio$Department == "Cardiology"))

# collection_set(): every Labs collection comes back in one pull.
labs <- fc %>% select(`Encounter ID`, collection_set("Labs")) %>% collect()
stopifnot("collection set expands to its collections" =
            all(c("Lab Panel", "Lab Analyte", "Lipid = LDL") %in% names(labs)))

# Timestamps: numeric epoch milliseconds by default, POSIXct when the server runs native_timestamps=true.
dates <- fc %>% select(`Encounter Date`) %>% collect()
stopifnot("Encounter Date is numeric or a date-time, never text" =
            is.numeric(dates$`Encounter Date`) || inherits(dates$`Encounter Date`, "POSIXct"))
# dates = TRUE converts the FC's is_timestamp columns whatever the server setting; other numerics stay.
dated <- fc %>% select(`Encounter Date`, `Blood Pressure = Systolic`) %>% collect(dates = TRUE)
stopifnot("dates = TRUE gives POSIXct" = inherits(dated$`Encounter Date`, "POSIXct"),
          "non-timestamp numerics stay numeric" = is.numeric(dated$`Blood Pressure = Systolic`))

# Opt-in factors: single_valued categoricals become factors only when asked; multi-valued stays text.
plain   <- fc %>% select(Department, Conditions) %>% collect()
factors <- fc %>% select(Department, Conditions) %>% collect(factors = TRUE)
stopifnot("default keeps plain strings" = is.character(plain$Department),
          "factors = TRUE turns Department into a factor" = is.factor(factors$Department),
          "multi-valued Conditions stays a string" = is.character(factors$Conditions))

cat("PASS: discovery, head(n), collection sets, timestamps, opt-in factors\n")
